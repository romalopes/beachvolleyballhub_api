# Delivers a public contact enquiry and notifies platform staff (IDENTITY-259).
#
# The reliability rules this job encodes:
#   * only the id crosses the queue boundary, so a retry survives a redeploy;
#   * the message row is committed *before* this job is enqueued, so a delivery
#     failure can never lose the message;
#   * `emailed_at` / `notified_at` are the idempotency guards, so a retry (or a
#     duplicate enqueue) cannot send the same notification twice;
#   * no external HTTP happens inside a database transaction;
#   * failures are logged without message content and re-raised, so Solid Queue's
#     retry policy and the existing error monitoring see them.
class ContactMessageDeliveryJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(contact_message_id)
    message = ContactMessage.find_by(id: contact_message_id)
    return if message.nil?

    deliver_email(message)
    publish_notifications(message)
  rescue StandardError => e
    Rails.logger.error(
      "[contact] delivery failed for contact_message=#{contact_message_id}: #{e.class}: #{e.message}"
    )
    raise
  end

  private

  def deliver_email(message)
    return if message.emailed_at.present?

    recipients = ContactRecipients.list
    if recipients.empty?
      # Misconfiguration is an operator problem, not a reason to fail the
      # message: it stays stored and visible in the inbox.
      Rails.logger.warn(
        "[contact] #{ContactRecipients::ENV_KEY} is not configured; " \
        "contact_message=#{message.id} was not emailed"
      )
      ContactRecipients.invalid.each do |address|
        Rails.logger.warn("[contact] ignoring invalid recipient address: #{address}")
      end
      return
    end

    ContactMessageMailer.notification(message, inbox_url: inbox_url_for(message)).deliver_now
    mark_delivered(message, :emailed_at)
  end

  # Notifies every platform Admin and Curator through the existing notification
  # service. Organisation-scoped roles live on a different table, so an
  # organisation's administrators are never picked up here; coaches are not
  # notified at all.
  def publish_notifications(message)
    return if message.notified_at.present?

    recipients = platform_staff_accounts
    if recipients.empty?
      Rails.logger.warn("[contact] no platform staff accounts to notify for contact_message=#{message.id}")
    else
      Notifications::WorkflowEvents.contact_message_received(message, recipients: recipients)
    end

    mark_delivered(message, :notified_at)
  end

  # `update_columns` skips validations/callbacks deliberately: this is delivery
  # bookkeeping on an already-valid message, and it must not be able to fail
  # because of unrelated model rules.
  def mark_delivered(message, column)
    message.update_columns(column => Time.current, updated_at: Time.current)
  end

  def platform_staff_accounts
    Account.where(user_id: staff_user_ids).to_a
  end

  # Users holding the platform-wide staff roles. Notifications are addressed to
  # Accounts, so a staff user without an Account simply receives none.
  def staff_user_ids
    UserRole.joins(:role).where(roles: { name: %w[admin curator] }).select(:user_id)
  end

  def inbox_url_for(message)
    base = ENV.fetch("FRONTEND_URL", "http://localhost:5174").to_s.chomp("/")
    "#{base}/settings/contact-messages/#{message.id}"
  end
end
