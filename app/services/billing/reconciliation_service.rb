module Billing
  # Repairs the local mirror by comparing it with Stripe (IDENTITY-116, Phase 5).
  #
  # Run on a schedule (see `BillingReconciliationJob`). It repairs the two failure
  # modes a webhook cannot: a delivery that never arrived, and a delivery that was
  # permanently rejected. It never invents entitlement: a local subscription whose
  # Stripe record is gone is reported, not silently downgraded or deleted, because
  # revoking paid access needs a human decision.
  #
  # Every repair goes through the same `WebhookProcessor` used for live events, so
  # there is exactly one implementation of "what does this Stripe object mean?".
  # Synthetic events are stored in `billing_events` as an audit trail of the repair.
  class ReconciliationService
    Summary = Struct.new(:checked, :processed, :repaired, :failed, :missing_in_stripe,
                         :orphaned, :errors, keyword_init: true) do
      def to_h
        {
          checked: checked, processed: processed, repaired: repaired, failed: failed,
          missing_in_stripe: missing_in_stripe, orphaned: orphaned, errors: errors
        }
      end
    end

    def initialize(limit: 500)
      @limit = limit
      @summary = Summary.new(checked: 0, processed: 0, repaired: 0, failed: 0,
                             missing_in_stripe: 0, orphaned: 0, errors: [])
    end

    attr_reader :summary

    def call
      Configuration.validate_api!

      BillingSubscription.stripe_managed.limit(@limit).find_each do |local|
        reconcile_local(local)
      end

      detect_orphaned_stripe_subscriptions
      AuditLogger.event("reconciliation.completed", **summary.to_h)
      summary
    end

    private

    def reconcile_local(local)
      summary.checked += 1
      tracked = %w[status stripe_price_id current_period_end cancel_at_period_end]
      before = local.attributes.slice(*tracked)

      stripe_subscription = StripeGateway.retrieve_subscription(local.stripe_subscription_id)
      result = apply(stripe_subscription, "reconciliation")

      case result
      when :processed
        summary.processed += 1
        summary.repaired += 1 if local.reload.attributes.slice(*tracked) != before
      when :failed, :duplicate
        summary.failed += 1
      end
    rescue Stripe::InvalidRequestError => e
      # Local record points at a Stripe subscription that no longer exists.
      summary.missing_in_stripe += 1
      AuditLogger.warn_event("reconciliation.missing_in_stripe",
                             owner_type: local.billable_type, owner_id: local.billable_id,
                             stripe_subscription_id: local.stripe_subscription_id,
                             message: e.message)
    rescue Stripe::StripeError => e
      summary.errors << { stripe_subscription_id: local.stripe_subscription_id, error: e.message }
      AuditLogger.error_event("reconciliation.error", e,
                              owner_type: local.billable_type, owner_id: local.billable_id)
    rescue StandardError => e
      summary.errors << { stripe_subscription_id: local.stripe_subscription_id, error: e.message }
      AuditLogger.error_event("reconciliation.error", e)
    end

    # A missed `customer.subscription.created` leaves an active Stripe subscription
    # with no local record. The customer mapping identifies the owner and the Price
    # identifies the plan, so the same processor can create the missing row.
    def detect_orphaned_stripe_subscriptions
      BillingCustomer.limit(@limit).find_each do |customer|
        subscriptions = StripeGateway.list_customer_subscriptions(customer.stripe_customer_id)
        Array(subscriptions.respond_to?(:data) ? subscriptions.data : subscriptions["data"]).each do |stripe_subscription|
          stripe_id = stripe_subscription.respond_to?(:id) ? stripe_subscription.id : stripe_subscription["id"]
          next if BillingSubscription.exists?(stripe_subscription_id: stripe_id)

          summary.orphaned += 1
          result = apply(stripe_subscription, "reconciliation")
          summary.repaired += 1 if result == :processed
        end
      rescue Stripe::StripeError => e
        summary.errors << { stripe_customer_id: customer.stripe_customer_id, error: e.message }
        AuditLogger.error_event("reconciliation.orphan_scan_failed", e,
                                stripe_customer_id: customer.stripe_customer_id)
      end
    end

    # Feeding the object through the live webhook processor keeps reconciliation
    # and webhook behaviour identical. The synthetic event id makes each run an
    # auditable row without colliding with a real Stripe event.
    def apply(stripe_subscription, source)
      event = {
        "id" => "reconciliation_#{SecureRandom.hex(12)}",
        "type" => "customer.subscription.updated",
        "created" => Time.current.to_i,
        "data" => {
          "object" => stripe_subscription.respond_to?(:to_hash) ? stripe_subscription.to_hash : stripe_subscription
        }
      }
      WebhookProcessor.new(event).call
    end
  end
end
