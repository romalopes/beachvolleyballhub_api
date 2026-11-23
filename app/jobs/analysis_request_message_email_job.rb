# Emails one analysis-request message to the other side of the conversation
# (IDENTITY-265): submitter → crew, team → submitter. Internal notes are never
# emailed. Mirrors the submission job: off-request delivery, a warning (not a
# failure) when no recipient exists, and `emailed_at` makes retries safe.
class AnalysisRequestMessageEmailJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = AnalysisRequestMessage.find_by(id: message_id)
    return if message.nil? || message.internal? || message.emailed_at.present?

    request = message.analysis_request
    return if recipients(message, request).empty?

    AnalysisRequestsMailer.new_message(message).deliver_now
    message.update_columns(emailed_at: Time.current, updated_at: Time.current)
  rescue StandardError => e
    Rails.logger.error(
      "[analysis_request] message email failed for ##{message_id}: #{e.class}: #{e.message}"
    )
    raise
  end

  private

  def recipients(message, request)
    if message.from_submitter?
      AnalysisRequestRecipients.list
    else
      [ request.account&.email.presence || request.guest_email.presence ].compact
    end
  end
end
