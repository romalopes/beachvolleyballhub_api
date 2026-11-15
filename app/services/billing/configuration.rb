module Billing
  # Server-side Stripe configuration (IDENTITY-116, Phase 3).
  #
  # Everything the integration needs comes from the server environment. Nothing
  # here is ever exposed to the SPA: the publishable key is the only value the
  # frontend could safely use, and this application does not need it (Checkout is
  # hosted by Stripe and redirected to by URL).
  #
  # A missing secret is a *safe* failure: `validate!` names the variables that are
  # absent without printing any value, and the API returns
  # `billing_not_configured` rather than half-working.
  class Configuration
    DEFAULT_CURRENCY = "AUD"
    DEFAULT_FRONTEND_URL = "http://localhost:5174"
    DEFAULT_GRACE_PERIOD_DAYS = 7
    REQUIRED_SETTINGS = %w[STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET].freeze

    class << self
      def secret_key
        ENV["STRIPE_SECRET_KEY"].presence
      end

      def publishable_key
        ENV["STRIPE_PUBLISHABLE_KEY"].presence
      end

      def webhook_secret
        ENV["STRIPE_WEBHOOK_SECRET"].presence
      end

      def frontend_url
        (ENV["APP_FRONTEND_URL"].presence || ENV["FRONTEND_URL"].presence || DEFAULT_FRONTEND_URL)
          .to_s.sub(%r{/+\z}, "")
      end

      # Stripe replaces the `{CHECKOUT_SESSION_ID}` placeholder itself, so it is
      # included for reconciliation without the API ever trusting it as proof.
      def success_url
        url = ENV["STRIPE_SUCCESS_URL"].presence || "#{frontend_url}/billing/return?checkout=success"
        append_session_placeholder(url)
      end

      def cancel_url
        url = ENV["STRIPE_CANCEL_URL"].presence || "#{frontend_url}/billing/return?checkout=cancelled"
        append_session_placeholder(url)
      end

      def portal_return_url
        ENV["STRIPE_PORTAL_RETURN_URL"].presence || "#{frontend_url}/billing"
      end

      def grace_period_days
        value = Integer(ENV.fetch("BILLING_GRACE_PERIOD_DAYS", DEFAULT_GRACE_PERIOD_DAYS.to_s), exception: false)
        value && value >= 0 ? value : DEFAULT_GRACE_PERIOD_DAYS
      end

      def grace_period
        grace_period_days.days
      end

      # Enforcement is opt-in per environment. Until the premium operations and
      # catalogue are approved for a deployment, existing role-based behaviour
      # must not change underneath it. Production turns this on.
      def enforcement_enabled?
        ActiveModel::Type::Boolean.new.cast(ENV["BILLING_ENFORCEMENT_ENABLED"]).present?
      end

      # The environment variable name for a plan's yearly Stripe Price, e.g.
      # `player` -> `STRIPE_PLAYER_YEARLY_PRICE_ID`.
      def price_env_key(slug)
        "STRIPE_#{slug.to_s.upcase.gsub(/[^A-Z0-9]/, '_')}_YEARLY_PRICE_ID"
      end

      def configured?
        REQUIRED_SETTINGS.all? { |name| ENV[name].present? }
      end

      def validate!
        missing = REQUIRED_SETTINGS.reject { |name| ENV[name].present? }
        return true if missing.empty?

        raise Errors::NotConfigured,
              "Billing is not configured: missing #{missing.join(', ')}"
      end

      # API calls need the secret key; the webhook needs its signing secret. They
      # are validated separately so a checkout can work while (for example) a
      # webhook secret is being rotated, and the error names only what is missing.
      def validate_api!
        return true if secret_key.present?

        raise Errors::NotConfigured,
              "Billing is not configured: missing STRIPE_SECRET_KEY"
      end

      def validate_webhook!
        return true if webhook_secret.present?

        raise Errors::NotConfigured,
              "Billing is not configured: missing STRIPE_WEBHOOK_SECRET"
      end

      # Safe to expose (admin-only): names and presence, never values. Deliberately
      # reports whether each plan has a Price in either ENV or the database.
      def diagnostics
        plans = begin
          Subscription.ordered.map do |plan|
            {
              slug: plan.slug,
              price_configured: PriceCatalog.price_id_for(plan).present?,
              price_source: PriceCatalog.price_source(plan),
              currency: plan.currency,
              yearly_price_cents: plan.yearly_price_cents,
              active: plan.active?
            }
          end
        rescue ActiveRecord::StatementInvalid
          []
        end

        {
          secret_key_configured: secret_key.present?,
          publishable_key_configured: publishable_key.present?,
          webhook_secret_configured: webhook_secret.present?,
          configured: configured?,
          enforcement_enabled: enforcement_enabled?,
          grace_period_days: grace_period_days,
          frontend_url: frontend_url,
          success_url: success_url,
          cancel_url: cancel_url,
          missing_settings: REQUIRED_SETTINGS.reject { |name| ENV[name].present? },
          plans: plans
        }
      end

      private

      def append_session_placeholder(url)
        return url if url.include?("CHECKOUT_SESSION_ID")

        separator = url.include?("?") ? "&" : "?"
        "#{url}#{separator}session_id={CHECKOUT_SESSION_ID}"
      end
    end
  end
end
