module Api
  module V1
    module Billing
      # GET /api/v1/billing/history (IDENTITY-116, Phase 4/6).
      #
      # The owner's append-only lifecycle history: activations, renewals, plan
      # changes, payment failures and admin assignments. Scoped to an owner the
      # caller may manage, and never mixed between personal and organisation
      # billing.
      class HistoriesController < BaseController
        def index
          owner = resolved_owner
          entries = SubscriptionHistory
                    .for_owner(owner)
                    .includes(:subscription, :previous_subscription)
                    .recent
                    .limit(50)

          render json: {
            owner: { type: owner.class.name, id: owner.id },
            data: entries.map { |entry| ::Billing::Presenter.history(entry) }
          }
        end
      end
    end
  end
end
