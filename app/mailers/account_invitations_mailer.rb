class AccountInvitationsMailer < ApplicationMailer
  # Send invitation email to new user
  # Token is placed in URL fragment to avoid log exposure
  def invitation(invitation, raw_token)
    @invitation = invitation
    @raw_token = raw_token
    @invitee_email = invitation.invitee_email

    # The token is placed in the URL fragment (e.g., /accept-invitation#token=abc123)
    # This prevents the token from appearing in server logs or proxy caches
    headers["X- token-fragment"] = "true"

    mail(
      to: @invitee_email,
      subject: "You're invited to join BeachVolleyballHub",
      from: ENV.fetch("MAIL_FROM", "BVB Project <no-reply@example.com>")
    )
  end
end