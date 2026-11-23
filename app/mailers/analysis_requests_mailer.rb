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

  # Invoice delivery (IDENTITY-265). The PDF is generated on the job thread and
  # attached, so the submitter has a portable copy without logging in.
  #
  # @param invoice [AnalysisRequestInvoice]
  def invoice_to_submitter(invoice)
    @invoice = invoice
    @request = invoice.analysis_request
    @amount_aud = invoice.amount_aud
    @invoice_number = invoice.number
    @issued_on = invoice.created_at.in_time_zone(Time.zone).strftime("%A, %-d %B %Y")
    @payment_reference = invoice.external_reference.presence || invoice.number

    document = Invoices::PdfDocument.new(invoice)
    attachments[document.filename] = {
      mime_type: "application/pdf",
      content: document.render
    }

    mail(
      to: submitter_email(@request) || @request.guest_email,
      subject: "Invoice #{invoice.number} for analysis request #{@request.reference}"
    )
  end

  # A new conversation message (IDENTITY-265). The recipient depends on who
  # wrote it: the submitter's messages go to the crew (Reply-To the submitter),
  # team messages go to the submitter (Reply-To the author when known).
  #
  # @param message [AnalysisRequestMessage]
  def new_message(message)
    @message = message
    @request = message.analysis_request
    @author_name = author_name(message)
    @body = message.body
    @guest_access_url = guest_access_url(@request)
    @staff_url = frontend_url("/analysis-requests/#{@request.id}")
    @submitter_url = frontend_url("/my/analysis-requests")

    headers =
      if message.from_submitter?
        {
          to: AnalysisRequestRecipients.list,
          subject: "New message from #{@author_name} (#{@request.reference})",
          reply_to: submitter_email(@request)
        }
      else
        {
          to: submitter_email(@request) || @request.guest_email,
          subject: "New message about your analysis request (#{@request.reference})",
          reply_to: message.account&.email.presence
        }
      end

    mail(headers.compact)
  end

  private

  def author_name(message)
    if message.from_submitter?
      message.account&.full_name.presence || @request.guest_name.presence || "The submitter"
    else
      message.account&.full_name.presence || "The Beach Volleyball Hub team"
    end
  end

  def submitter_email(request)
    address = request.account&.email.presence || request.guest_email.presence
    return nil if address.blank?
    return nil unless address.to_s.match?(AnalysisRequestRecipients::EMAIL_FORMAT)

    address.to_s.strip
  end

  def guest_access_url(request)
    return nil unless request.guest_access_token.present?

    frontend_url("/analysis/guest/#{request.guest_access_token}")
  end

  def frontend_url(path)
    base = ENV.fetch("FRONTEND_URL", "http://localhost:5174").to_s.chomp("/")
    "#{base}#{path}"
  end
end
