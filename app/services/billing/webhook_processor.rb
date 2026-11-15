module Billing
  # Applies a signed Stripe webhook to local state (IDENTITY-116, Phase 5).
  #
  # Guarantees, in order of importance:
  #   1. Idempotent — a Stripe event id is unique in `billing_events`; a duplicate
  #      delivery is recognised and skipped without touching billing state.
  #   2. Correlated — the Stripe Customer must map to the owner this application
  #      created it for, and the Price must map to a configured plan. Metadata is
  #      checked *against* that mapping, never trusted on its own.
  #   3. Transactional — subscription, history and event status are written in one
  #      transaction, so a failure cannot leave half an activation behind.
  #   4. Order-tolerant — a stale event (older than the last applied one for the
  #      same subscription) is ignored rather than allowed to revert newer state.
  #   5. Never optimistic — no browser redirect, amount or client-supplied value
  #      is consulted. Stripe's event is the only input.
  #
  # Transient failures (Stripe API/DB unavailable) raise `TransientFailure`, which
  # the controller turns into a 5xx so Stripe retries. Permanent correlation
  # failures are recorded on the event and acknowledged, because retrying would
  # repeat the same mismatch.
  class WebhookProcessor
    HANDLED_EVENTS = %w[
      checkout.session.completed
      checkout.session.async_payment_succeeded
      checkout.session.async_payment_failed
      customer.subscription.created
      customer.subscription.updated
      customer.subscription.deleted
      invoice.paid
      invoice.payment_failed
      invoice.finalization_failed
    ].freeze

    SENSITIVE_KEY = /secret|signature|card|cvc|cvv|client_secret/i

    def initialize(event)
      @event = normalize(event)
    end

    attr_reader :event

    def call
      event_id = event["id"].to_s
      type = event["type"].to_s
      if event_id.blank? || type.blank?
        raise Errors::BillingError.new("Malformed Stripe event", code: "invalid_event", status: :bad_request)
      end

      existing = BillingEvent.find_by(stripe_event_id: event_id)
      if existing && %w[processed skipped].include?(existing.status)
        AuditLogger.event("webhook.duplicate", event_id: event_id, type: type, status: existing.status)
        return :duplicate
      end

      record = existing || create_event!(event_id, type)
      record.record_attempt!

      handler = "handle_#{type.tr('.', '_')}"
      unless respond_to?(handler, true)
        record.mark_skipped!("Unhandled event type: #{type}")
        AuditLogger.warn_event("webhook.skipped", event_id: event_id, type: type)
        return :skipped
      end

      AuditLogger.event("webhook.received", event_id: event_id, type: type, attempt: record.attempts)

      begin
        handler_result = nil
        ActiveRecord::Base.transaction do
          handler_result = send(handler, record)
          if handler_result == :out_of_order
            # A permanently stale event: acknowledge it (Stripe must not retry) but
            # do not pretend it changed anything.
            record.mark_skipped!("Ignored an out-of-order event older than the applied state")
          else
            record.mark_processed!
          end
        end
        AuditLogger.event("webhook.processed", event_id: event_id, type: type)
        handler_result == :out_of_order ? :out_of_order : :processed
      rescue Errors::TransientFailure
        raise
      rescue Errors::BillingError => e
        record.mark_failed!(e.message)
        AuditLogger.error_event("webhook.failed", e, event_id: event_id, type: type, code: e.code)
        :failed
      rescue ActiveRecord::RecordInvalid => e
        record.mark_failed!(e.record.errors.full_messages.to_sentence)
        AuditLogger.error_event("webhook.failed", e, event_id: event_id, type: type)
        :failed
      rescue ActiveRecord::RecordNotUnique => e
        record.mark_failed!(e.message)
        AuditLogger.error_event("webhook.failed", e, event_id: event_id, type: type)
        :failed
      rescue Stripe::StripeError => e
        # Leave the event at `received` so Stripe's retry can succeed later.
        AuditLogger.error_event("webhook.transient_failure", e, event_id: event_id, type: type)
        raise Errors::TransientFailure, e.message
      end
    end

    private

    # --- Event handlers ------------------------------------------------------

    def handle_checkout_session_completed(record)
      checkout_completed(record)
    end

    def handle_checkout_session_async_payment_succeeded(record)
      checkout_completed(record)
    end

    def handle_checkout_session_async_payment_failed(record)
      session = object
      row = BillingCheckoutSession.find_by(stripe_checkout_session_id: session["id"])
      row&.update!(status: "open")
      AuditLogger.warn_event("checkout.async_payment_failed",
                             session_id: session["id"],
                             owner_type: row&.billable_type, owner_id: row&.billable_id)
    end

    def handle_customer_subscription_created(record)
      sync_subscription(object, source: "webhook")
    end

    def handle_customer_subscription_updated(record)
      sync_subscription(object, source: "webhook")
    end

    def handle_customer_subscription_deleted(record)
      sync_subscription(object, source: "webhook")
    end

    def handle_invoice_paid(record)
      invoice = object
      subscription_id = id_of(invoice["subscription"])
      return log_unmatched_invoice("invoice.paid", invoice) if subscription_id.blank?

      local = BillingSubscription.find_by(stripe_subscription_id: subscription_id)
      return log_unmatched_invoice("invoice.paid", invoice) if local.nil?

      period_end = invoice_period_end(invoice)
      renewed = period_end.present? &&
                (local.current_period_end.nil? || period_end > local.current_period_end)

      local.apply_stripe_state!(
        status: local.status == "canceled" ? "canceled" : "active",
        grace_period_ends_at: nil,
        current_period_start: invoice_period_start(invoice) || local.current_period_start,
        current_period_end: period_end || local.current_period_end
      )

      if renewed
        HistoryRecorder.record!(
          billable: local.billable,
          plan: local.subscription,
          status: "renewal",
          source: "webhook",
          stripe_subscription_id: local.stripe_subscription_id,
          stripe_price_id: local.stripe_price_id,
          started_at: local.current_period_start,
          ended_at: local.current_period_end,
          metadata: { "invoice_id" => invoice["id"] }
        )
      end

      AuditLogger.event("invoice.paid",
                        owner_type: local.billable_type, owner_id: local.billable_id,
                        invoice_id: invoice["id"], period_end: local.current_period_end)
    end

    def handle_invoice_payment_failed(record)
      invoice = object
      subscription_id = id_of(invoice["subscription"])
      return log_unmatched_invoice("invoice.payment_failed", invoice) if subscription_id.blank?

      local = BillingSubscription.find_by(stripe_subscription_id: subscription_id)
      return log_unmatched_invoice("invoice.payment_failed", invoice) if local.nil?
      return if local.status == "canceled"

      grace_ends_at = Time.current + Configuration.grace_period
      local.apply_stripe_state!(status: "past_due", grace_period_ends_at: grace_ends_at)

      HistoryRecorder.record!(
        billable: local.billable,
        plan: local.subscription,
        status: "payment_failed",
        source: "webhook",
        stripe_subscription_id: local.stripe_subscription_id,
        stripe_price_id: local.stripe_price_id,
        metadata: {
          "invoice_id" => invoice["id"],
          "attempt_count" => invoice["attempt_count"],
          "grace_period_ends_at" => grace_ends_at.iso8601
        }
      )

      AuditLogger.warn_event("invoice.payment_failed",
                             owner_type: local.billable_type, owner_id: local.billable_id,
                             invoice_id: invoice["id"], grace_period_ends_at: grace_ends_at)
    end

    def handle_invoice_finalization_failed(record)
      invoice = object
      AuditLogger.warn_event("invoice.finalization_failed",
                             invoice_id: invoice["id"],
                             subscription_id: id_of(invoice["subscription"]),
                             message: invoice.dig("last_finalization_error", "message"))
    end

    # --- Shared flows --------------------------------------------------------

    def checkout_completed(record)
      session = object
      row = BillingCheckoutSession.find_by(stripe_checkout_session_id: session["id"])
      owner = owner_from_checkout(session, row)
      row&.mark_completed!

      expanded = session["subscription"].is_a?(Hash) ? session["subscription"] : nil
      if expanded.present?
        sync_subscription(expanded, source: "checkout", checkout_row: row)
      else
        # Stripe normally follows with customer.subscription.created. Correlating
        # the checkout now proves the owner/customer relationship; activation still
        # waits for the subscription event.
        AuditLogger.event("checkout.awaiting_subscription_event",
                          session_id: session["id"],
                          owner_type: owner.class.name, owner_id: owner.id,
                          stripe_subscription_id: id_of(session["subscription"]))
      end
    end

    def owner_from_checkout(session, row)
      metadata_owner = owner_from_metadata(session["metadata"])
      customer_owner = CustomerService.owner_for_stripe_customer(id_of(session["customer"]))

      if row.present?
        if metadata_owner.present? && metadata_owner != row.billable
          raise Errors::CorrelationFailed,
                "Checkout metadata owner does not match the stored session owner"
        end
        if customer_owner.present? && customer_owner != row.billable
          raise Errors::CorrelationFailed, "Checkout customer belongs to a different owner"
        end

        return row.billable
      end

      return customer_owner if customer_owner.present?

      raise Errors::CorrelationFailed, "Checkout session is not correlated to a local owner"
    end

    # Applies a Stripe subscription object (created/updated/deleted, or the
    # expanded object on a Checkout Session) to local state.
    def sync_subscription(subscription, source:, checkout_row: nil)
      subscription = subscription.to_hash.deep_stringify_keys if subscription.respond_to?(:to_hash)
      return :ignored if subscription.blank?

      stripe_id = subscription["id"].to_s
      customer_id = id_of(subscription["customer"])
      if stripe_id.blank? || customer_id.blank?
        raise Errors::CorrelationFailed, "Stripe subscription is missing an id or customer"
      end

      owner = CustomerService.owner_for_stripe_customer(customer_id)
      raise Errors::CorrelationFailed, "No local owner for Stripe customer #{customer_id}" if owner.nil?
      verify_metadata_owner!(owner, subscription["metadata"])

      price_id = price_id_from(subscription)
      plan = PriceCatalog.plan_for_price_id(price_id) ||
             Subscription.find_by(stripe_price_id: price_id)
      if plan.nil?
        raise Errors::CorrelationFailed, "Stripe Price #{price_id.inspect} is not in the plan catalogue"
      end
      unless plan.supports_owner?(owner.class.name)
        raise Errors::CorrelationFailed, "Plan #{plan.slug} cannot be sold to a #{owner.class.name}"
      end

      status = subscription["status"].to_s
      unless BillingSubscription::STATUSES.include?(status)
        raise Errors::CorrelationFailed, "Unexpected Stripe subscription status #{status.inspect}"
      end

      record = BillingSubscription.find_or_initialize_by(
        billable_type: owner.class.name, billable_id: owner.id
      )
      if record.persisted? && record.stripe_subscription_id.present? &&
         record.stripe_subscription_id != stripe_id
        raise Errors::CorrelationFailed, "Owner already has a different Stripe subscription"
      end
      if checkout_row.present? && checkout_row.billable != owner
        raise Errors::CorrelationFailed, "Checkout session owner does not match the subscription owner"
      end

      event_at = event_time
      return :out_of_order if out_of_order?(record, event_at)

      previous_plan = record.subscription
      previous_status = record.status
      new_record = record.new_record?

      record.assign_attributes(
        subscription: plan,
        status: status,
        stripe_customer_id: customer_id,
        stripe_subscription_id: stripe_id,
        stripe_price_id: price_id,
        current_period_start: time_of(subscription["current_period_start"]),
        current_period_end: time_of(subscription["current_period_end"]),
        cancel_at_period_end: subscription["cancel_at_period_end"] == true,
        canceled_at: time_of(subscription["canceled_at"]),
        ended_at: time_of(subscription["ended_at"]),
        trial_ends_at: time_of(subscription["trial_end"]),
        grace_period_ends_at: grace_for(record, status),
        metadata: merged_metadata(record, event_at)
      )
      clear_pending_change!(record)
      record.last_synced_at = Time.current
      record.save!

      changes = record.saved_changes.keys
      if new_record || changes.intersect?(%w[subscription_id status stripe_subscription_id canceled_at ended_at])
        HistoryRecorder.record_transition!(
          record,
          previous_plan: previous_plan,
          source: source,
          metadata: {
            "previous_status" => previous_status,
            "stripe_event_id" => event["id"],
            "reason" => new_record ? "subscription_activated" : "subscription_updated"
          }
        )
      end

      checkout_row&.update!(stripe_customer_id: customer_id)

      AuditLogger.event("subscription.synced",
                        owner_type: record.billable_type, owner_id: record.billable_id,
                        plan_slug: plan.slug, status: status,
                        stripe_subscription_id: stripe_id,
                        created: new_record)
      record
    end

    # --- Helpers -------------------------------------------------------------

    def verify_metadata_owner!(owner, metadata)
      metadata = (metadata || {}).stringify_keys
      type = metadata["owner_type"].presence
      id = metadata["owner_id"].presence
      return if type.blank? && id.blank?

      unless type.to_s == owner.class.name && id.to_s == owner.id.to_s
        raise Errors::CorrelationFailed,
              "Stripe metadata owner does not match the billing customer owner"
      end
    end

    def owner_from_metadata(metadata)
      metadata = (metadata || {}).stringify_keys
      type = metadata["owner_type"].to_s
      id = metadata["owner_id"].to_s
      return nil unless BillingSubscription::OWNER_TYPES.include?(type) && id.present?

      type.constantize.find_by(id: id)
    end

    def object
      (event.dig("data", "object") || {}).stringify_keys
    end

    def event_time
      time_of(event["created"]) || Time.current
    end

    def out_of_order?(record, event_at)
      return false if record.blank? || !record.persisted?

      last = record.metadata.to_h["last_event_created_at"]
      return false if last.blank? || event_at.blank?

      Time.zone.parse(last.to_s) > event_at
    rescue ArgumentError
      false
    end

    def merged_metadata(record, event_at)
      record.metadata.to_h.stringify_keys.merge(
        "last_event_created_at" => event_at&.utc&.iso8601
      ).compact
    end

    def clear_pending_change!(record)
      return unless record.pending_subscription_id.present?
      return unless record.subscription_id == record.pending_subscription_id

      record.pending_subscription_id = nil
      record.pending_change_requested_at = nil
      record.pending_change_effective_at = nil
    end

    def grace_for(record, status)
      return nil unless status == "past_due"
      return record.grace_period_ends_at if record.grace_period_ends_at.present? &&
                                            record.grace_period_ends_at > Time.current

      Time.current + Configuration.grace_period
    end

    def price_id_from(subscription)
      items = subscription.dig("items", "data") if subscription.key?("items")
      first = Array(items).first
      price = first && (first["price"] || first["plan"])
      id = price.is_a?(Hash) ? price["id"] : price
      id.presence || id_of(subscription["plan"])
    end

    def invoice_period_end(invoice)
      first_line = Array(invoice.dig("lines", "data")).first
      time_of(first_line&.dig("period", "end")) ||
        time_of(invoice["period_end"])
    end

    def invoice_period_start(invoice)
      first_line = Array(invoice.dig("lines", "data")).first
      time_of(first_line&.dig("period", "start")) ||
        time_of(invoice["period_start"])
    end

    def id_of(value)
      case value
      when String then value.presence
      when Hash then value["id"].presence
      else
        value.respond_to?(:id) ? value.id : nil
      end
    end

    def time_of(value)
      return nil if value.blank?
      return value.change(usec: 0) if value.is_a?(Time) || value.is_a?(DateTime)
      return value.to_time if value.respond_to?(:to_time) && !value.is_a?(Numeric)

      Time.zone.at(value.to_i)
    rescue ArgumentError, TypeError
      nil
    end

    def log_unmatched_invoice(type, invoice)
      AuditLogger.warn_event("invoice.unmatched",
                             event_type: type,
                             invoice_id: invoice["id"],
                             stripe_subscription_id: id_of(invoice["subscription"]))
      :ignored
    end

    def create_event!(event_id, type)
      BillingEvent.create!(
        stripe_event_id: event_id,
        event_type: type,
        stripe_object_id: id_of(object["id"]),
        status: "received",
        received_at: Time.current,
        stripe_created_at: time_of(event["created"]),
        payload: sanitize(event)
      )
    rescue ActiveRecord::RecordNotUnique
      BillingEvent.find_by!(stripe_event_id: event_id)
    end

    def sanitize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, inner), result|
          next if key.to_s.match?(SENSITIVE_KEY)

          result[key] = sanitize(inner)
        end
      when Array
        value.map { |inner| sanitize(inner) }
      else
        value
      end
    end

    def normalize(value)
      hash = value.respond_to?(:to_hash) ? value.to_hash : value
      hash.deep_stringify_keys
    end
  end
end
