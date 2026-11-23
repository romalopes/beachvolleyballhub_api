require "test_helper"

# Invoice numbering and email bookkeeping (IDENTITY-265).
class AnalysisRequestInvoiceTest < ActiveSupport::TestCase
  setup do
    @request = analysis_requests(:guest_one)
  end

  test "number is a stable INV- identifier" do
    invoice = @request.analysis_request_invoices.create!(
      amount_cents: 4900, currency: "AUD", status: "pending"
    )

    assert_equal format("INV-%04d", invoice.id), invoice.number
  end

  test "mark_emailed! records the delivery timestamp without touching status" do
    invoice = @request.analysis_request_invoices.create!(
      amount_cents: 4900, currency: "AUD", status: "sent", sent_at: Time.current
    )

    invoice.mark_emailed!

    invoice.reload
    assert invoice.emailed?
    assert invoice.emailed_at.present?
    assert_equal "sent", invoice.status
  end

  test "amount_aud formats cents" do
    invoice = @request.analysis_request_invoices.create!(
      amount_cents: 123_456, currency: "AUD", status: "pending"
    )

    assert_equal "$1234.56 AUD", invoice.amount_aud
  end
end
