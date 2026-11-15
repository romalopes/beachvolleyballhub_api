module Api
  module V1
    module Billing
      # Shared authentication and error contract for the billing endpoints
      # (IDENTITY-116, Phase 4).
      #
      # Every billing action resolves its owner through `Billing::OwnerResolver`,
      # which verifies that the caller may manage that owner. A caller-supplied
      # `owner_id` is therefore never trusted on its own: a member of a club who is
      # not an owner/administrator gets a 403, exactly like a stranger would.
      class BaseController < ApplicationController
        before_action :require_authentication

        rescue_from ::Billing::Errors::BillingError, with: :render_billing_error

        private

        def render_billing_error(error)
          render json: { error: error.message, code: error.code }.merge(error.details || {}),
                 status: error.status
        end

        def owner_scope
          { owner_type: params[:owner_type], owner_id: params[:owner_id] }
        end

        def resolved_owner
          @resolved_owner ||= ::Billing::OwnerResolver.new(Current.user).resolve(**owner_scope)
        end
      end
    end
  end
end
