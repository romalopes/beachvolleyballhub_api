class Admin::Accounts::InvitationService
  class Error < StandardError; end

  def self.call(inviter:, first_name:, last_name:, email:, send_invitation:)
    # Run all operations in a transaction
    ActiveRecord::Base.transaction do
      # Case 1: Create user + account + contact + invitation + send email
      if email.present? && send_invitation
        # Create User without password - invitee will set their own
        user = User.create!(
          email: email,
          first_name: first_name,
          last_name: last_name,
          is_verified: false,
          password_digest: nil
        )

        # Create Account linked to User
        account = Account.create!(
          user: user,
          contact_detail: ContactDetail.create!(
            first_name: first_name,
            last_name: last_name,
            email: email
          )
        )

        # Create AccountInvitation
        invitation = AccountInvitation.create!(
          token_digest: AccountInvitation.generate_token_digest,
          invitee_email: email,
          inviter_id: inviter.id,
          status: "active",
          expires_at: 7.days.from_now
        )

        # Send invitation email
        AccountInvitationsMailer.invitation(invitation, invitation.token).deliver_later

        # Return result with invitation
        SuccessResult.new(invitation: invitation, user: user, account: account)
      # Case 2: Create user + account + contact without invitation
      elsif email.present? && !send_invitation
        user = User.create!(
          email: email,
          first_name: first_name,
          last_name: last_name,
          is_verified: false,
          password_digest: nil
        )

        account = Account.create!(
          user: user,
          contact_detail: ContactDetail.create!(
            first_name: first_name,
            last_name: last_name,
            email: email
          )
        )

        SuccessResult.new(invitation: nil, user: user, account: account)
      # Case 3: Create user + account + contact without email
      else
        user = User.create!(
          first_name: first_name,
          last_name: last_name,
          is_verified: false,
          password_digest: nil
        )

        account = Account.create!(
          user: user,
          contact_detail: ContactDetail.create!(
            first_name: first_name,
            last_name: last_name
          )
        )

        SuccessResult.new(invitation: nil, user: user, account: account)
      end
    end
  end

  # Result object for the service call
  class Result
    attr_reader :success, :error

    def initialize(success: false, error: nil)
      @success = success
      @error = error
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  class SuccessResult < Result
    attr_reader :invitation, :user, :account

    def initialize(invitation:, user:, account:)
      super(success: true)
      @invitation = invitation
      @user = user
      @account = account
    end
  end

  class FailureResult < Result
    attr_reader :errors

    def initialize(errors:)
      super(success: false, error: errors)
      @errors = errors
    end
  end

  # Helper to wrap results
  class Wrapper
    def self.call(&block)
      new.call(&block)
    end

    def call
      begin
        yield
        SuccessResult.new
      rescue StandardError => e
        FailureResult.new(errors: [e.message])
      end
    end
  end
end