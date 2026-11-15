module Billing
  # Thin wrapper around the official Stripe Ruby SDK (IDENTITY-116).
  #
  # Every Stripe call goes through this class so that:
  #   * the secret key is configured in exactly one place;
  #   * tests can stub one seam (`Billing::StripeGateway.stub(:create_checkout_session, ...)`)
  #     instead of reaching into SDK internals;
  #   * controllers and services never see a Stripe key.
  #
  # The gateway is intentionally ignorant of business rules. It validates neither
  # owner permissions nor plan eligibility — those live in the services above it.
  class StripeGateway
    class << self
      def configure!
        raise Errors::NotConfigured if Configuration.secret_key.blank?

        Stripe.api_key = Configuration.secret_key
        Stripe.max_network_retries = 2
      end

      def create_customer(email:, name:, metadata: {})
        configure!
        params = { email: email, name: name, metadata: metadata }.compact
        Stripe::Customer.create(params)
      end

      def retrieve_customer(customer_id)
        configure!
        Stripe::Customer.retrieve(customer_id)
      end

      def create_checkout_session(params)
        configure!
        Stripe::Checkout::Session.create(params)
      end

      def retrieve_checkout_session(session_id, expand: [])
        configure!
        Stripe::Checkout::Session.retrieve({ id: session_id, expand: expand.presence }.compact)
      end

      def create_portal_session(customer:, return_url:)
        configure!
        Stripe::BillingPortal::Session.create({ customer: customer, return_url: return_url })
      end

      def update_subscription(subscription_id, params)
        configure!
        Stripe::Subscription.update(subscription_id, params)
      end

      def retrieve_subscription(subscription_id)
        configure!
        Stripe::Subscription.retrieve(subscription_id)
      end

      # The Stripe subscription item id is required to replace a Price. It is not
      # persisted locally because Stripe is the authority for it.
      def current_item_id(subscription_id)
        subscription = retrieve_subscription(subscription_id)
        items = if subscription.respond_to?(:items)
          subscription.items&.data
        else
          subscription.dig("items", "data")
        end
        first = Array(items).first
        return nil if first.nil?

        first.respond_to?(:id) ? first.id : first["id"]
      end

      def retrieve_subscription_price_ids(subscription_id)
        configure!
        subscription = Stripe::Subscription.retrieve(subscription_id)
        Array(subscription.items&.data).map { |item| item.price&.id }.compact
      end

      def retrieve_price(price_id)
        configure!
        Stripe::Price.retrieve(price_id)
      end

      def list_customer_subscriptions(customer_id, status: "all")
        configure!
        Stripe::Subscription.list({ customer: customer_id, status: status, limit: 10 })
      end

      # Deferred downgrade: a subscription schedule with the current Price until the
      # end of the paid period, then the new Price. Stripe applies the phase change
      # itself and emits `customer.subscription.updated`, which is what makes the
      # local plan change authoritative rather than optimistic.
      def schedule_plan_change(subscription_id:, new_price_id:, effective_at: nil)
        configure!
        schedule = Stripe::SubscriptionSchedule.create({ from_subscription: subscription_id })
        current_phase = Array(schedule.phases).first
        current_items = Array(current_phase&.items).map do |item|
          { price: item.price&.id, quantity: item.quantity || 1 }.compact
        end
        current_items = [ { price: new_price_id, quantity: 1 } ] if current_items.empty?

        end_date = effective_at&.to_i || current_phase&.end_date
        phase_one = {
          items: current_items,
          start_date: current_phase&.start_date,
          end_date: end_date
        }.compact
        phase_two = { items: [ { price: new_price_id, quantity: 1 } ] }

        Stripe::SubscriptionSchedule.update(schedule.id, {
          phases: [ phase_one, phase_two ],
          end_behavior: "release",
          metadata: { managed_by: "beachvolleyballhub", purpose: "scheduled_plan_change" }
        })
      end

      def verify_webhook(payload, signature, secret)
        Stripe::Webhook.construct_event(payload, signature, secret)
      end
    end
  end
end
