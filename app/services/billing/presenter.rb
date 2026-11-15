module Billing
  # JSON shapes for the billing API (IDENTITY-116).
  #
  # Rendering lives here rather than in each controller so the public pricing page,
  # the account billing page, the organisation billing page and the admin console
  # cannot drift into three slightly different plan shapes.
  #
  # Nothing secret is included: no Price IDs, no keys, no payment method details.
  # The Stripe Price ID is deliberately absent — the SPA has no use for it.
  class Presenter
    CURRENCY_SYMBOLS = {
      "AUD" => "A$", "NZD" => "NZ$", "USD" => "$", "EUR" => "€", "GBP" => "£"
    }.freeze

    class << self
      def plan(plan, include_features: true)
        payload = {
          id: plan.id,
          name: plan.name,
          slug: plan.slug,
          description: plan.description,
          active: plan.active?,
          visible: plan.visible?,
          popular: plan.popular?,
          default: plan.default?,
          position: plan.position,
          currency: plan.currency,
          yearly_price_cents: plan.yearly_price_cents,
          yearly_price: format("%.2f", plan.yearly_price_cents / 100.0),
          price_label: price_label(plan),
          owner_scope: plan.owner_scope,
          included_users: plan.included_users,
          history_limit: plan.history_limit,
          purchasable: plan.purchasable?,
          stripe_price_configured: PriceCatalog.price_id_for(plan).present?
        }
        payload[:features] = plan.features.active.ordered.map { |feature| feature(feature) } if include_features
        payload
      end

      def feature(feature)
        {
          id: feature.id,
          name: feature.name,
          slug: feature.slug,
          description: feature.description,
          active: feature.active?,
          position: feature.position
        }
      end

      def plan_feature_assignment(association)
        feature(association.subscription_feature).merge(position: association.position,
                                                       association_id: association.id)
      end

      def plan_summary(plan)
        { id: plan.id, slug: plan.slug, name: plan.name }
      end

      # The billing status of one owner. `can_manage`/`can_checkout` are computed
      # from the acting user, not from the owner record, so a member of an
      # organisation cannot learn that billing exists by reading a boolean.
      def status(owner:, viewer: nil, can_manage: true)
        resolver = Entitlements::Resolver.new(owner)
        record = resolver.billing_record
        customer = BillingCustomer.find_by(billable_type: owner.class.name, billable_id: owner.id)

        {
          owner: {
            type: owner.class.name,
            id: owner.id,
            name: OwnerContact.name(owner),
            can_manage: can_manage
          },
          plan: resolver.plan ? plan(resolver.plan, include_features: true) : nil,
          status: resolver.status,
          entitled: resolver.entitled?,
          free_fallback: resolver.free_fallback?,
          features: resolver.effective_features.map { |feature| feature(feature) },
          limits: limits(resolver),
          usage: Entitlements::Usage.summary(owner),
          subscription: subscription_payload(record),
          billing_customer: { present: customer.present?, email: customer&.email },
          can_checkout: can_manage && resolver.free_fallback?,
          can_open_portal: can_manage && customer.present?,
          can_change_plan: can_manage && record.present? && record.stripe_managed?,
          viewer_id: viewer&.id
        }
      end

      # Only the customer-safe subset of a history row's metadata. Internal
      # correlation ids (Stripe event ids, actor ids) stay in the admin view.
      CUSTOMER_HISTORY_METADATA_KEYS = %w[
        reason invoice_id previous_status attempt_count grace_period_ends_at
      ].freeze

      def history(entry)
        {
          id: entry.id,
          plan: entry.subscription && plan_summary(entry.subscription),
          previous_plan: entry.previous_subscription && plan_summary(entry.previous_subscription),
          status: entry.status,
          source: entry.source,
          started_at: entry.started_at,
          ended_at: entry.ended_at,
          canceled_at: entry.canceled_at,
          created_at: entry.created_at,
          stripe_subscription_id: entry.stripe_subscription_id,
          metadata: entry.metadata.to_h.slice(*CUSTOMER_HISTORY_METADATA_KEYS)
        }
      end

      def checkout(result)
        {
          checkout_url: result.url,
          session_id: result.session_id,
          reused: result.reused == true
        }
      end

      def limits(resolver)
        {
          included_users: limit_payload(resolver, :included_users),
          history_limit: limit_payload(resolver, :history_limit)
        }
      end

      def limit_payload(resolver, name)
        value = resolver.limit_for(name)
        {
          value: value,
          unlimited: Entitlements::Quota.unlimited?(value),
          label: limit_label(name, value)
        }
      end

      def limit_label(name, value)
        return "Not applicable" if value.nil?

        case name.to_sym
        when :included_users
          value.zero? ? "Owner access only" : "#{value} included #{"user".pluralize(value)}"
        when :history_limit
          value.zero? ? "No extended history" : "#{value} history entries"
        else
          value.to_s
        end
      end

      private

      def price_label(plan)
        return "Free" if plan.free?

        symbol = CURRENCY_SYMBOLS.fetch(plan.currency, "#{plan.currency} ")
        "#{symbol}#{format("%.2f", plan.yearly_price_cents / 100.0)}/year"
      end

      def subscription_payload(record)
        return nil if record.nil?

        {
          id: record.id,
          status: record.status,
          stripe_customer_id: record.stripe_customer_id,
          stripe_subscription_id: record.stripe_subscription_id,
          current_period_start: record.current_period_start,
          current_period_end: record.current_period_end,
          cancel_at_period_end: record.cancel_at_period_end?,
          canceled_at: record.canceled_at,
          ended_at: record.ended_at,
          grace_period_ends_at: record.grace_period_ends_at,
          last_synced_at: record.last_synced_at,
          pending_change: record.pending_subscription && {
            plan: plan_summary(record.pending_subscription),
            requested_at: record.pending_change_requested_at,
            effective_at: record.pending_change_effective_at
          }
        }
      end
    end
  end
end
