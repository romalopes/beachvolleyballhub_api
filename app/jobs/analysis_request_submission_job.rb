# Sends the two emails that accompany a new analysis request (IDENTITY-265):
# one to the team, one to the submitter. Mirrors ContactMessageDeliveryJob:
# delivery happens off-request, each channel is recorded independently, and a
# missing recipient list degrades to a logged warning instead of a failed
# submission.
class AnalysisRequestSubmissionJob < ApplicationJob
  queue_as :default

  # Retries are safe: each channel is skipped once its *_emailed_at is set, so a
  # retry can never double-send the half that already succeeded.
  def perform(analysis_request)
    @request = analysis_request

    deliver_to_crew
    deliver_to_submitter
  end

  private

  attr_reader :request

  def deliver_to_crew
    return if request.crew_emailed_at.present?

    recipients = AnalysisRequestRecipients.list
    if recipients.empty?
      Rails.logger.warn(
        "[analysis_request] #{AnalysisRequestRecipients::ENV_KEY} is not configured and " \
        "no admin/curator accounts have an email; crew notification skipped for #{request.reference}"
      )
      return
    end

    AnalysisRequestsMailer.submitted_to_crew(request).deliver_now
    mark(request, :crew_emailed_at)
  rescue StandardError => e
    Rails.logger.error(
      "[analysis_request] crew email failed for #{request.reference}: #{e.class}: #{e.message}"
    )
    raise
  end

  def deliver_to_submitter
    return if request.submitter_emailed_at.present?

    email = request.account&.email.presence || request.guest_email.presence
    if email.blank?
      Rails.logger.warn(
        "[analysis_request] no submitter email for #{request.reference}; confirmation skipped"
      )
      return
    end

    AnalysisRequestsMailer.submitted_to_submitter(request).deliver_now
    mark(request, :submitter_emailed_at)
  rescue StandardError => e
    Rails.logger.error(
      "[analysis_request] submitter email failed for #{request.reference}: #{e.class}: #{e.message}"
    )
    raise
  end

  def mark(record, column)
    record.update_columns(column => Time.current, updated_at: Time.current)
  end
end
