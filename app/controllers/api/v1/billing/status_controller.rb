module Api
  module V1
    module Billing
      # GET /api/v1/billing/status (IDENTITY-116, Phase 4).
      #
      # The authoritative state the SPA polls after returning from Checkout. It
      # reports what the webhook has confirmed, which is why the return page shows
      # "processing" until this endpoint says the plan is active.
      class StatusController < BaseController
        def show
          owner = resolved_owner
          can_manage = ::Billing::OwnerResolver.new(Current.user).can_manage?(owner)

          render json: ::Billing::Presenter.status(
            owner: owner,
            viewer: Current.user,
            can_manage: can_manage
          )
        end
      end
    end
  end
end
