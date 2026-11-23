require "test_helper"

class AnalysisRequestTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @user = @account.user
  end

  test "valid authenticated request requires account" do
    request = AnalysisRequest.new(
      title: "Test Analysis",
      description: "Test description",
      account: @account
    )
    assert request.valid?
  end

  test "valid guest request requires name and email" do
    request = AnalysisRequest.new(
      title: "Test Analysis",
      description: "Test description",
      guest_name: "Jane Guest",
      guest_email: "jane@example.com"
    )
    assert request.valid?
  end

  test "guest request without name is invalid" do
    request = AnalysisRequest.new(
      title: "Test Analysis",
      guest_email: "jane@example.com"
    )
    assert_not request.valid?
    assert_includes request.errors[:base], "Must have either account or guest name/email"
  end

  test "guest request without email is invalid" do
    request = AnalysisRequest.new(
      title: "Test Analysis",
      guest_name: "Jane Guest"
    )
    assert_not request.valid?
    assert_includes request.errors[:base], "Must have either account or guest name/email"
  end

  test "guest request generates access token" do
    request = AnalysisRequest.create!(
      title: "Test Analysis",
      guest_name: "Jane Guest",
      guest_email: "jane@example.com"
    )
    assert_not_nil request.guest_access_token
    assert_equal 43, request.guest_access_token.length # urlsafe_base64(32) = 43 chars
  end

  test "guest request generates reference" do
    request = AnalysisRequest.create!(
      title: "Test Analysis",
      guest_name: "Jane Guest",
      guest_email: "jane@example.com"
    )
    assert_match /\AANL-\d{4}-\d{4}\z/, request.reference
  end

  test "reference is sequential per year" do
    request1 = AnalysisRequest.create!(title: "Test 1", guest_name: "A", guest_email: "a@example.com")
    request2 = AnalysisRequest.create!(title: "Test 2", guest_name: "B", guest_email: "b@example.com")
    assert_equal request1.reference.split("-").last.to_i + 1, request2.reference.split("-").last.to_i
  end

  test "workflow status transitions" do
    request = AnalysisRequest.create!(title: "Test", guest_name: "A", guest_email: "a@example.com")
    assert_equal "submitted", request.workflow_status

    request.accept!(price_cents: 4900)
    assert_equal "accepted", request.workflow_status
    assert_equal 4900, request.price_cents

    request = AnalysisRequest.create!(title: "Test 2", guest_name: "B", guest_email: "b@example.com")
    request.reject!("Not suitable")
    assert_equal "rejected", request.workflow_status
    assert_equal "Not suitable", request.rejection_reason

    request = AnalysisRequest.create!(title: "Test 3", guest_name: "C", guest_email: "c@example.com")
    request.quote!(9900)
    assert_equal "quoted", request.workflow_status
    assert_equal 9900, request.price_cents
  end

  test "payment status transitions" do
    request = AnalysisRequest.create!(title: "Test", guest_name: "A", guest_email: "a@example.com")
    request.accept!(price_cents: 4900)
    assert_equal "unpaid", request.payment_status

    request.mark_invoice_sent!
    assert_equal "invoice_sent", request.payment_status

    request.mark_paid!
    assert_equal "paid", request.payment_status
    assert_equal "in_progress", request.workflow_status

    request = AnalysisRequest.create!(title: "Test 2", guest_name: "B", guest_email: "b@example.com")
    request.cancel!
    assert_equal "cancelled", request.workflow_status
    assert_equal "cancelled", request.payment_status
  end

  test "guest? and authenticated?" do
    guest_request = AnalysisRequest.create!(title: "Test", guest_name: "A", guest_email: "a@example.com")
    auth_request = AnalysisRequest.create!(title: "Test", account: @account)

    assert guest_request.guest?
    assert_not guest_request.authenticated?

    assert auth_request.authenticated?
    assert_not auth_request.guest?
  end

  test "find_by_guest_access!" do
    request = AnalysisRequest.create!(title: "Test", guest_name: "A", guest_email: "a@example.com")
    found = AnalysisRequest.find_by_guest_access!(request.guest_access_token)
    assert_equal request, found

    assert_raises(ActiveRecord::RecordNotFound) { AnalysisRequest.find_by_guest_access!("invalid") }
  end

  test "scopes work" do
    # Create test records with unique titles to avoid fixture interference
    submitted = AnalysisRequest.create!(title: "Scope Submitted", guest_name: "A", guest_email: "a@example.com", workflow_status: "submitted")
    accepted = AnalysisRequest.create!(title: "Scope Accepted", guest_name: "B", guest_email: "b@example.com", workflow_status: "accepted")
    in_progress = AnalysisRequest.create!(title: "Scope In Progress", guest_name: "C", guest_email: "c@example.com", workflow_status: "in_progress")
    completed = AnalysisRequest.create!(title: "Scope Completed", guest_name: "D", guest_email: "d@example.com", workflow_status: "completed")

    assert_includes AnalysisRequest.submitted, submitted
    assert_includes AnalysisRequest.accepted, accepted
    assert_includes AnalysisRequest.in_progress, in_progress
    assert_includes AnalysisRequest.completed, completed
  end

  test "price_cents must be non-negative" do
    request = AnalysisRequest.new(title: "Test", guest_name: "A", guest_email: "a@example.com", price_cents: -100)
    assert_not request.valid?
  end

  test "title length validation" do
    request = AnalysisRequest.new(title: "a" * 161, guest_name: "A", guest_email: "a@example.com")
    assert_not request.valid?
  end
end