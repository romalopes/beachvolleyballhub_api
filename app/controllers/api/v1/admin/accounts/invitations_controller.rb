module Api
  module V1
    module Admin
      module Accounts
        class InvitationsController < ApplicationController
          before_action :authorize_admin!

          # POST /api/v1/admin/account/invitation
          # Creates a new account and optionally sends an invitation
          def create
            invitation_params = params.require(:account_invitation).permit(
              :first_name, :last_name, :email, :send_invitation
            )

            result = ::Admin::Accounts::InvitationService.call(
              inviter: current_user,
              first_name: invitation_params[:first_name],
              last_name: invitation_params[:last_name],
              email: invitation_params[:email],
              send_invitation: invitation_params[:send_invitation] == "1"
            )

            if result.success?
              render json: {
                invitation: result.invitation&.summary,
                user_id: result.user.id,
                account_id: result.account.id
              }, status: :created
            else
              render json: { errors: result.errors }, status: :unprocessable_entity
            end
          end
        end
      end
    end
  end
end