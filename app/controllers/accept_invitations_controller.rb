class AcceptInvitationsController < ApplicationController
  before_action :authenticate_user!

  # GET /accept-invitation
  # Renders form where invitee sets password
  def edit
    # Find invitation by token_digest (matches SHA256(raw_token))
    @invitation = AccountInvitation.find_by(
      token_digest: AccountInvitation.generate_token_digest_from_fragment(params[:token])
    )

    if @invitation.nil?
      flash[:alert] = "Invalid invitation token"
      redirect_to root_path and return
    end

    # Check if invitation is still valid
    status = @invitation.effective_status
    if status == "expired"
      flash[:alert] = "This invitation has expired"
      redirect_to root_path and return
    end

    if @invitation.used?
      flash[:alert] = "This invitation has already been used"
      redirect_to root_path and return
    end
  end

  # PATCH /accept-invitation/:id
  # Submits password form to accept invitation
  def update
    @invitation = AccountInvitation.find(params[:id])

    # Check if invitation is still valid
    if @invitation.expired?
      flash[:alert] = "This invitation has expired"
      render :edit and return
    end

    if @invitation.used?
      flash[:alert] = "This invitation has already been used"
      render :edit and return
    end

    # Validate password
    unless params[:password] == params[:password_confirmation]
      flash[:alert] = "Passwords do not match"
      render :edit and return
    end

    if params[:password].length < 6
      flash[:alert] = "Password must be at least 6 characters"
      render :edit and return
    end

    # Accept the invitation
    ActiveRecord::Base.transaction do
      # Update User with password and mark as verified
      @invitation.user.update!(
        password_digest: BCrypt::Password.create(params[:password]),
        is_verified: true
      )

      # Mark invitation as accepted
      @invitation.update!(
        status: "accepted",
        used_by: @invitation.user.id
      )

      # Create User session
      login(@invitation.user)

      flash[:notice] = "Welcome! Your account has been activated."
      redirect_to onboarding_path
    end
  rescue => e
    flash[:alert] = "Error accepting invitation: #{e.message}"
    render :edit
  end

  private

  # Extract token from fragment parameter
  def token_param
    params[:token]
  end
end