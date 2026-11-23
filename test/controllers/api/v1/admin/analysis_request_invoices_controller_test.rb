require "test_helper"

# Invoice ledger API (IDENTITY-265): staff-only listing with filters/totals and
# PDF email delivery.
class Api::V1::Admin::AnalysisRequestInvoicesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @account = accounts(:one)
    @user = @account.user
    @session, @headers = sign_in_with_api_token(@user)
  end

  test "members cannot read the ledger" do
    get api_v1_admin_analysis_request_invoices_path, headers: @headers

    assert_response :forbidden
  end

  test "staff see every invoice with request, submitter and totals" do
    @user.add_role(:curator)

    get api_v1_admin_analysis_request_invoices_path, headers: @headers

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body["meta"]["total_count"]
    assert_equal 14_800, body["totals"]["amount_cents"]
    assert_equal "AUD 148.00", body["totals"]["amount_aud"]

    guest = body["data"].find { |row| row["analysis_request"]["reference"] == "ANL-2026-0002" }
    assert_equal "Jane Guest", guest["submitter"]["name"]
    assert_equal "jane@example.com", guest["submitter"]["email"]
    assert_equal "paid", guest["status"]
  end

  test "filters by stored status" do
    @user.add_role(:admin)

    get api_v1_admin_analysis_request_invoices_path, params: { status: "paid" }, headers: @headers

    statuses = response.parsed_body["data"].map { |row| row["status"] }
    assert_equal [ "paid" ], statuses
    assert_equal 9_900, response.parsed_body["totals"]["amount_cents"]
  end

  test "unpaid view covers pending and sent invoices" do
    @user.add_role(:admin)

    get api_v1_admin_analysis_request_invoices_path, params: { status: "unpaid" }, headers: @headers

    statuses = response.parsed_body["data"].map { |row| row["status"] }
    assert_equal [ "sent" ], statuses
  end

  test "search matches request reference, submitter and external reference" do
    @user.add_role(:admin)

    [ "0002", "jane", "BT-1002" ].each do |term|
      get api_v1_admin_analysis_request_invoices_path, params: { q: term }, headers: @headers

      assert_response :success
      references = response.parsed_body["data"].map { |row| row["analysis_request"]["reference"] }
      assert_equal [ "ANL-2026-0002" ], references, "expected #{term} to match only the guest invoice"
    end
  end

  test "filters by issue date range" do
    @user.add_role(:admin)

    get api_v1_admin_analysis_request_invoices_path,
        params: { from: 7.days.ago.to_date.iso8601, to: Date.current.iso8601 },
        headers: @headers

    references = response.parsed_body["data"].map { |row| row["analysis_request"]["reference"] }
    assert_equal [ "ANL-2026-0002" ], references
  end

  test "overdue filter surfaces sent invoices older than 30 days" do
    @user.add_role(:admin)

    get api_v1_admin_analysis_request_invoices_path, params: { overdue: "1" }, headers: @headers

    numbers = response.parsed_body["data"].map { |row| row["number"] }
    assert_equal [ analysis_request_invoices(:one).number ], numbers
  end

  test "staff can email a specific invoice" do
    @user.add_role(:admin)

    assert_enqueued_with(job: AnalysisRequestInvoiceEmailJob,
                         args: [ analysis_request_invoices(:guest_paid).id ]) do
      post email_api_v1_admin_analysis_request_invoice_path(analysis_request_invoices(:guest_paid)),
           headers: @headers
    end

    assert_response :accepted
    assert response.parsed_body["queued"]
  end

  test "emailing an invoice without a submitter address is rejected" do
    @user.add_role(:admin)
    request = analysis_requests(:guest_one)
    request.update_columns(guest_email: nil)
    invoice = analysis_request_invoices(:guest_paid)

    post email_api_v1_admin_analysis_request_invoice_path(invoice), headers: @headers

    assert_response :unprocessable_entity
  end
end
