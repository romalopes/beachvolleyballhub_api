require "test_helper"

class AccountInvitationTest < ActiveSupport::TestCase
  test "is valid with all required fields" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com",
      status: "active",
      expires_at: 7.days.from_now,
      invited_by: users(:one)
    )
    assert invitation.valid?
  end

  test "token_digest must be present" do
    invitation = AccountInvitation.new(status: "active", expires_at: 7.days.from_now)
    assert_not invitation.valid?
    assert_includes invitation.errors[:token_digest], "can't be blank"
  end

  test "status must be valid enum value" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com",
      expires_at: 7.days.from_now
    )
    invitation.status = "invalid"
    assert_not invitation.valid?
  end

  test "invitee_email format validation" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "not-an-email",
      expires_at: 7.days.from_now
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:invitee_email], "format is invalid"
  end

  test "invitee_email is normalized (downcased, trimmed)" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "  TEST@EXAMPLE.COM  ",
      expires_at: 7.days.from_now
    )
    assert invitation.valid?
    # After save, email should be normalized
    assert_equal "test@example.com", invitation.invitee_email
  end

  test "expires_at must be present" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com"
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:expires_at], "can't be blank"
  end

  test "status default is active" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com"
    )
    assert_equal "active", invitation.status
  end

  test "activatable? returns true for valid active invitation" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com",
      status: "active",
      expires_at: 7.days.from_now
    )
    assert invitation.activatable?
  end

  test "activatable? returns false for expired invitation" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com",
      status: "active",
      expires_at: 1.day.ago
    )
    refute invitation.activatable?
  end

  test "activatable? returns false for already used invitation" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com",
      status: "used",
      expires_at: 7.days.from_now,
      used_by: users(:one)
    )
    refute invitation.activatable?
  end

  test "summary returns correct hash" do
    invitation = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "test@example.com",
      status: "active",
      expires_at: 7.days.from_now,
      emailed_at: Time.current
    )
    summary = invitation.summary
    assert_equal "test@example.com", summary[:invitee_email]
    assert_not_nil summary[:emailed_at]
    assert_nil summary[:used_at]
  end

  test "cannot have two active invitations with same email" do
    AccountInvitation.create!(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "duplicate@example.com",
      status: "active",
      expires_at: 7.days.from_now,
      invited_by: users(:one)
    )

    duplicate = AccountInvitation.new(
      token_digest: AccountInvitation.generate_token_digest,
      invitee_email: "duplicate@example.com",
      status: "active",
      expires_at: 7.days.from_now,
      invited_by: users(:one)
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:invitee_email], "has already been taken"
  end
end