module Billing
  # The errors the billing API exposes deliberately. Each one maps to a stable
  # response code so the SPA can react without parsing English prose.
  module Errors
    class BillingError < StandardError
      attr_reader :code, :status, :details

      def initialize(message, code:, status: :unprocessable_entity, details: {})
        super(message)
        @code = code
        @status = status
        @details = details
      end
    end

    class NotConfigured < BillingError
      def initialize(message = "Billing is not configured")
        super(message, code: "billing_not_configured", status: :service_unavailable)
      end
    end

    class OwnerNotEligible < BillingError
      def initialize(message = "You cannot manage billing for this owner")
        super(message, code: "billing_owner_not_eligible", status: :forbidden)
      end
    end

    class PlanNotPurchasable < BillingError
      def initialize(message = "That plan is not available for purchase")
        super(message, code: "subscription_plan_not_purchasable")
      end
    end

    class PlanIncompatible < BillingError
      def initialize(message = "That plan is not available for this owner")
        super(message, code: "subscription_plan_incompatible")
      end
    end

    class PriceNotConfigured < BillingError
      def initialize(message = "The plan has no configured Stripe Price")
        super(message, code: "stripe_price_not_configured", status: :service_unavailable)
      end
    end

    class InvalidPrice < BillingError
      def initialize(message = "The configured Stripe Price is not a yearly AUD price")
        super(message, code: "stripe_price_invalid", status: :service_unavailable)
      end
    end

    class AlreadySubscribed < BillingError
      def initialize(message = "This owner already has a paid subscription; change it instead")
        super(message, code: "subscription_already_active", status: :conflict)
      end
    end

    class NoActiveSubscription < BillingError
      def initialize(message = "There is no paid subscription to change")
        super(message, code: "subscription_missing")
      end
    end

    class SamePlan < BillingError
      def initialize(message = "That is already the current plan")
        super(message, code: "subscription_same_plan")
      end
    end

    class ChangeAlreadyPending < BillingError
      def initialize(message = "A plan change is already pending confirmation")
        super(message, code: "subscription_change_pending", status: :conflict)
      end
    end

    class WebhookSignatureInvalid < BillingError
      def initialize(message = "Invalid Stripe webhook signature")
        super(message, code: "webhook_signature_invalid", status: :bad_request)
      end
    end

    # A permanent correlation failure (owner/customer/price mismatch). It is not
    # retryable: retrying would only repeat the same mismatch, so the webhook is
    # acknowledged and the event is marked failed for an administrator to inspect.
    class CorrelationFailed < BillingError
      def initialize(message)
        super(message, code: "billing_correlation_failed")
      end
    end

    # A transient failure (Stripe API unavailable, database error). The webhook
    # returns 5xx so Stripe retries.
    class TransientFailure < BillingError
      def initialize(message)
        super(message, code: "billing_transient_failure", status: :internal_server_error)
      end
    end
  end
end
