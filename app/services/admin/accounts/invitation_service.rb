class Admin::Accounts::InvitationService
  class Error < StandardError; end

  def self.call(inviter:, first_name:, last_name:, email:, send_invitation:)
    return FailureResult.new(errors: [ "Email is required to send an invitation" ]) if email.blank?

    ActiveRecord::Base.transaction do
      # The invitee gets a random unusable password (users.password_digest is
      # NOT NULL); they set their own when they accept the invitation.
      user = User.create!(
        email_address: email,
        password: SecureRandom.hex(32)
      )

      # ContactDetail is built (not created) so the Account association sets
      # contact_details.account_id before the row is inserted.
      account = Account.create!(
        user: user,
        contact_detail: ContactDetail.new(
          first_name: first_name,
          last_name: last_name,
          email: email
        )
      )

      invitation = nil
      if send_invitation
        # The raw token only exists here — the database stores its SHA-256
        # digest, so the raw token must be handed to the mailer directly.
        raw_token = SecureRandom.urlsafe_base64(32)
        invitation = AccountInvitation.create!(
          token_digest: Digest::SHA256.hexdigest(raw_token),
          invitee_email: email,
          invited_by_id: inviter.id,
          status: "active",
          expires_at: 7.days.from_now,
          emailed_at: Time.current
        )

        AccountInvitationsMailer.invitation(invitation, raw_token).deliver_later
      end

      SuccessResult.new(invitation: invitation, user: user, account: account)
    end
  rescue ActiveRecord::RecordInvalid => e
    FailureResult.new(errors: e.record.errors.full_messages)
  rescue StandardError => e
    FailureResult.new(errors: [ e.message ])
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
        FailureResult.new(errors: [ e.message ])
      end
    end
  end
end
