require "test_helper"

# Invoice delivery (IDENTITY-265). The job owns the state changes that follow a
# successful send, so the request/invoice cannot be left promising an email that
# never left the building.
class AnalysisRequestInvoiceEmailJobTest < ActiveJob::TestCase
  setup do
    @request = AnalysisRequest.create!(
      title: "Serve review",
      guest_name: "Jane Guest",
      guest_email: "jane@example.com",
      price_cents: 4900
    )
    @invoice = @request.analysis_request_invoices.create!(
      amount_cents: 4900, currency: "AUD", status: "pending"
    )
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "emails the PDF and records the send" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      AnalysisRequestInvoiceEmailJob.perform_now(@invoice.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "jane@example.com" ], mail.to
    assert mail.attachments.any? { |a| a.mime_type == "application/pdf" }

    @invoice.reload
    assert_equal "sent", @invoice.status
    assert @invoice.sent_at.present?
    assert @invoice.emailed_at.present?

    @request.reload
    assert_equal "invoice_sent", @request.payment_status
    assert @request.invoice_sent_at.present?
  end

  test "is safe to resend without downgrading paid invoices" do
    @invoice.update!(status: "paid", paid_at: Time.current)
    @request.update!(payment_status: "paid", paid_at: Time.current)

    AnalysisRequestInvoiceEmailJob.perform_now(@invoice.id)

    @invoice.reload
    @request.reload
    assert_equal "paid", @invoice.status
    assert_equal "paid", @request.payment_status
    assert @invoice.emailed_at.present?
  end

  test "skips delivery when the submitter has no email" do
    @request.update_columns(guest_email: nil)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      AnalysisRequestInvoiceEmailJob.perform_now(@invoice.id)
    end

    assert_nil @invoice.reload.emailed_at
  end
end
