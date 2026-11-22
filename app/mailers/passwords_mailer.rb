class PasswordsMailer < ApplicationMailer
  def reset_password_instructions(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end

  # Admin-sent invitation for an existing unverified user. Uses the same
  # single-use password-setup token as the reset flow, but the copy frames
  # the email as an invitation to join rather than a reset the user requested.
  def invitation(user)
    @user = user
    mail subject: "You're invited to join BVBhub", to: user.email_address
  end
end
