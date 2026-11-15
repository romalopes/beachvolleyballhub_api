module Billing
  # Resolves which Stripe Price (and therefore which internal plan) a request is
  # for (IDENTITY-116, Phase 3).
  #
  # Environment variables take precedence over the catalogue column so that test
  # and live deployments can point at different Stripe accounts without editing
  # data. The database column is the fallback for plans created through the admin
  # UI. A browser-supplied Price ID is never consulted.
  class PriceCatalog
    class << self
      def price_id_for(plan)
        return nil if plan.blank?

        ENV[Configuration.price_env_key(plan.slug)].presence || plan.stripe_price_id.presence
      end

      # "environment", "database" or nil — surfaced in diagnostics so an operator
      # can tell which mapping is in force.
      def price_source(plan)
        return nil if plan.blank?
        return "environment" if ENV[Configuration.price_env_key(plan.slug)].present?
        return "database" if plan.stripe_price_id.present?

        nil
      end

      def require_price_id!(plan)
        price_id = price_id_for(plan)
        raise Errors::PriceNotConfigured if price_id.blank?

        price_id
      end

      # Resolves a Stripe Price back to an internal plan. Only configured Prices
      # are considered, so an unexpected Price in a webhook cannot be mapped to a
      # plan it was not sold as.
      def plan_for_price_id(price_id)
        return nil if price_id.blank?

        price_id = price_id.to_s
        Subscription.ordered.detect { |plan| price_id_for(plan) == price_id }
      end

      def expected_currency
        Configuration::DEFAULT_CURRENCY
      end
    end
  end
end
