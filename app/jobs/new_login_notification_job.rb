# frozen_string_literal: true

# Enqueued after every successful login (email/password).
#
# Receives the user's id and the serialisable `LoginDetails` hash so nothing
# from the original request survives into the background job. The email is
# delivered inside this job so delivery failures use this job's retry policy
# instead of depending on a second queued MailDeliveryJob.
#
# Failures are logged and retried — they must never bubble back into the
# login response.
class NewLoginNotificationJob < ApplicationJob
  queue_as :background

  # Rails 8.1 renamed the backoff strategy to :polynomially_longer (the old
  # :exponentially_longer symbol was removed and raises at retry time).
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(user_id, details_hash)
    user = User.find_by(id: user_id)
    return if user.nil? || user.email_address.blank?
    return if details_hash.blank?

    # The plain hash — not the LoginDetails object — is what crosses the job
    # boundary. The mailer rehydrates its own LoginDetails before delivery.
    SecurityMailer.new_login_email(user, details_hash).deliver_now
  rescue StandardError => e
    Rails.logger.error(
      "[security] new-login notification failed for user #{user_id}: #{e.class}: #{e.message}"
    )
    raise
  end
end
