# Transactional email for "Hire an Analysis" (IDENTITY-265).
#
# Two messages accompany a new submission:
#   * submitted_to_crew      — the team needs everything to triage the request
#                              without opening the app; Reply-To is the submitter.
#   * submitted_to_submitter — confirmation of receipt, the reference, what
#                              happens next, and (for guests) the secure link
#                              that lets them follow the process.
#
# Delivery is orchestrated by AnalysisRequestSubmissionJob, which resolves the
# recipients and records when each channel succeeded.
class AnalysisRequestsMailer < ApplicationMailer
  # @param request [AnalysisRequest]
  def submitted_to_crew(request)
    @request = request
    @submitted_at = request.submitted_at || Time.current
    @time_zone = Time.zone.name
    @videos = request.analysis_request_videos
    @submitter_email = submitter_email(request)

    headers = {
      to: AnalysisRequestRecipients.list,
      subject: "New analysis request #{request.reference}: #{request.title}"
    }
    # Reply straight to the submitter when we have a usable address; never use
    # it as From (SPF/DMARC, and it would look like the platform is the sender).
    headers[:reply_to] = @submitter_email if @submitter_email
    mail(headers)
  end

  # @param request [AnalysisRequest]
  def submitted_to_submitter(request)
    @request = request
    @submitted_at = request.submitted_at || Time.current
    @time_zone = Time.zone.name
    @guest_access_url = guest_access_url(request)

    mail(
      to: submitter_email(request) || request.guest_email,
      subject: "We received your analysis request (#{request.reference})"
    )
  end

  private

  def submitter_email(request)
    address = request.account&.email.presence || request.guest_email.presence
    return nil if address.blank?
    return nil unless address.to_s.match?(AnalysisRequestRecipients::EMAIL_FORMAT)

    address.to_s.strip
  end

  def guest_access_url(request)
    return nil unless request.guest_access_token.present?

    base = ENV.fetch("FRONTEND_URL", "http://localhost:5174").to_s.chomp("/")
    "#{base}/analysis/guest/#{request.guest_access_token}"
  end
end
