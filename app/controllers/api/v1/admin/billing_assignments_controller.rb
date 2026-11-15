module Api
  module V1
    module Admin
      # Manual plan assignment and billing inspection (IDENTITY-116).
      #
      # Support tooling, not a second billing system: an assignment needs a reason,
      # is written to history and the audit log, and refuses to overwrite a
      # subscription Stripe owns (the next webhook would revert it anyway).
      class BillingAssignmentsController < ApplicationController
        before_action :authorize_admin!

        def create
          record = ::Billing::AssignmentService.new(
            actor: Current.user,
            owner_type: params[:owner_type],
            owner_id: params[:owner_id],
            plan_slug: params[:plan_slug].presence || params.dig(:assignment, :plan_slug),
            reason: params[:reason].presence || params.dig(:assignment, :reason)
          ).call

          render json: {
            billing_subscription: {
              id: record.id,
              owner_type: record.billable_type,
              owner_id: record.billable_id,
              plan_slug: record.subscription.slug,
              status: record.status
            }
          }, status: :created
        rescue ::Billing::Errors::BillingError => e
          render json: { error: e.message, code: e.code }, status: e.status
        end
      end
    end
  end
end
