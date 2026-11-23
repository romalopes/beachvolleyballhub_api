# Emails an invoice (with a generated PDF) to the submitter (IDENTITY-265).
#
# Delivery happens off the request thread, mirroring AnalysisRequestSubmissionJob:
# a missing address degrades to a logged warning, and a failure raises so the
# queue retries. Resending is intentional (staff may click "Email invoice"
# again), so the job is not idempotent; it only records `emailed_at` on success.
class AnalysisRequestInvoiceEmailJob < ApplicationJob
  queue_as :default

  def perform(invoice_id)
    invoice = AnalysisRequestInvoice.find_by(id: invoice_id)
    return if invoice.nil?

    request = invoice.analysis_request
    email = request.account&.email.presence || request.guest_email.presence
    if email.blank?
      Rails.logger.warn(
        "[analysis_request] no submitter email for #{request.reference}; invoice #{invoice.number} not emailed"
      )
      return
    end

    AnalysisRequestsMailer.invoice_to_submitter(invoice).deliver_now

    invoice.mark_emailed!
    mark_invoice_sent(invoice)
    mark_request_invoice_sent(request)
  rescue StandardError => e
    Rails.logger.error(
      "[analysis_request] invoice email failed for ##{invoice_id}: #{e.class}: #{e.message}"
    )
    raise
  end

  private

  def mark_invoice_sent(invoice)
    return if invoice.status == "paid"

    invoice.update!(status: "sent", sent_at: invoice.sent_at || Time.current)
  end

  # Never downgrade a paid request; otherwise move it to invoice_sent so the
  # submitter-facing status matches the email they just received.
  def mark_request_invoice_sent(request)
    return if request.payment_status == "paid"

    request.update!(
      payment_status: "invoice_sent",
      invoice_sent_at: request.invoice_sent_at || Time.current
    )
  end
end
