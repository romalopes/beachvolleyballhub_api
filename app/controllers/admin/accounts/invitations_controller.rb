class Admin::Accounts::InvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  # POST /admin/accounts/invitation
  # Creates a new account and optionally sends an invitation
  def create
    invitation_params = params.require(:account_invitation).permit(
      :first_name, :last_name, :email, :send_invitation
    )

    Admin::Accounts::InvitationService.call(
      inviter: current_user,
      first_name: invitation_params[:first_name],
      last_name: invitation_params[:last_name],
      email: invitation_params[:email],
      send_invitation: invitation_params[:send_invitation] == "1"
    ) do |result|
      if result.success?
        render json: result.invitation, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_entity
      end
    end
  end

  private

  def authorize_admin!
    unless current_user&.admin?
      render json: { error: "Admin access required" }, status: :forbidden
    end
  end
end