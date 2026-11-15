module Api
  module V1
    module Billing
      # POST /api/v1/billing/change_subscription (IDENTITY-116, Phase 6).
      #
      # One endpoint for the three lifecycle requests because they share the same
      # authorization and the same "Stripe confirms it" contract:
      #   { action: "change", plan_slug: "coach" }  — upgrade or downgrade
      #   { action: "cancel" }                      — cancel at period end
      #   { action: "resume" }                      — reverse a pending cancellation
      #
      # The response is a *request acknowledgement*. Local entitlement does not
      # change here; the webhook applies the confirmed state.
      class ChangesController < BaseController
        def create
          result = ::Billing::PlanChangeService.new(
            user: Current.user,
            action: params[:action_name].presence || params[:change].presence || "change",
            plan_slug: params[:plan_slug],
            **owner_scope
          ).call

          render json: result
        end
      end
    end
  end
end
