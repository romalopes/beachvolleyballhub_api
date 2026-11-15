module Api
  module V1
    # Public subscription catalogue (IDENTITY-116, Phase 4).
    #
    # The pricing page is API-driven: prices, features and limits come from here,
    # never from hardcoded React constants. Only visible, active plans are exposed.
    # Stripe Price IDs and any secret stay server-side.
    class SubscriptionsController < ApplicationController
      def index
        plans = Subscription.visible_and_active
                           .includes(subscription_subscription_features: :subscription_feature)
                           .ordered

        render json: {
          data: plans.map { |plan| ::Billing::Presenter.plan(plan) },
          meta: {
            currency: ::Billing::Configuration::DEFAULT_CURRENCY,
            billing_configured: ::Billing::Configuration.configured?,
            enforcement_enabled: ::Billing::Configuration.enforcement_enabled?
          }
        }
      end
    end
  end
end
