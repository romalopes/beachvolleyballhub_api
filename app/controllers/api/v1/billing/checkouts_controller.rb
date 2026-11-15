module Api
  module V1
    module Billing
      # POST /api/v1/billing/checkout (IDENTITY-116, Phase 4).
      #
      # Accepts an internal plan slug only. Amount, currency and Stripe Price are
      # resolved server-side; anything the browser sends about money is ignored.
      class CheckoutsController < BaseController
        def create
          result = ::Billing::CheckoutService.new(
            user: Current.user,
            plan_slug: params[:plan_slug],
            **owner_scope
          ).call

          render json: ::Billing::Presenter.checkout(result), status: :created
        end
      end
    end
  end
end
