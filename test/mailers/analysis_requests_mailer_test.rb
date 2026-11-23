require "test_helper"

# Transactional email for "Hire an Analysis" submissions (IDENTITY-265).
#
# Pinned here: the crew message reaches every configured recipient with the
# submitter as Reply-To, the confirmation reaches the submitter, and guests get
# their secure access link while account holders do not.
class AnalysisRequestsMailerTest < ActionMailer::TestCase
  setup do
    @previous_recipients = ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"]
    @previous_frontend = ENV["FRONTEND_URL"]
    ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"] = "coach@bvb.test, admin@bvb.test"
    ENV["FRONTEND_URL"] = "https://bvb.test"

    @guest_request = AnalysisRequest.create!(
      title: "Jump serve review",
      description: "Focus on toss height and contact point.",
      guest_name: "Jane Guest",
      guest_email: "jane@example.com",
      package_key: "single_match",
      price_cents: 4900
    )
    @guest_request.analysis_request_videos.create!(
      source_type: "external",
      external_url: "https://youtu.be/abc123"
    )
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    restore_env("ANALYSIS_REQUEST_NOTIFICATION_EMAILS", @previous_recipients)
    restore_env("FRONTEND_URL", @previous_frontend)
  end

  def restore_env(key, value)
    value.nil? ? ENV.delete(key) : ENV[key] = value
  end

  test "crew email goes to every configured recipient" do
    email = AnalysisRequestsMailer.submitted_to_crew(@guest_request).deliver_now

    assert_equal [ "coach@bvb.test", "admin@bvb.test" ], email.to
    assert_includes email.subject, @guest_request.reference
    assert_includes email.subject, "Jump serve review"
  end

  test "crew email replies to the submitter, never sends as them" do
    email = AnalysisRequestsMailer.submitted_to_crew(@guest_request).deliver_now

    assert_equal [ "jane@example.com" ], email.reply_to
    refute_includes email[:from].to_s, "jane@example.com"
  end

  test "crew email carries everything needed to triage" do
    email = AnalysisRequestsMailer.submitted_to_crew(@guest_request).deliver_now
    body = email.text_part.body.to_s + email.html_part.body.to_s

    assert_includes body, "Jane Guest"
    assert_includes body, "jane@example.com"
    assert_includes body, "Single Match Analysis"
    assert_includes body, "$49.00 AUD"
    assert_includes body, "Focus on toss height and contact point."
    assert_includes body, "https://youtu.be/abc123"
  end

  test "submitter confirmation includes the reference and next steps" do
    email = AnalysisRequestsMailer.submitted_to_submitter(@guest_request).deliver_now
    body = email.text_part.body.to_s + email.html_part.body.to_s

    assert_equal [ "jane@example.com" ], email.to
    assert_includes email.subject, @guest_request.reference
    assert_includes body, @guest_request.reference
    assert_includes body, "What happens next"
    assert_includes body, "invoice"
  end

  test "guest confirmation carries a private access link" do
    email = AnalysisRequestsMailer.submitted_to_submitter(@guest_request).deliver_now
    body = email.text_part.body.to_s + email.html_part.body.to_s

    assert_includes body, "https://bvb.test/analysis/guest/#{@guest_request.guest_access_token}"
  end

  test "authenticated submitter confirmation uses the account email and no guest link" do
    account = accounts(:one)
    account.contact_detail.update!(email: "member@example.com")
    request = AnalysisRequest.create!(
      title: "Account request",
      account: account
    )

    email = AnalysisRequestsMailer.submitted_to_submitter(request).deliver_now
    body = email.text_part.body.to_s + email.html_part.body.to_s

    assert_equal [ "member@example.com" ], email.to
    refute_includes body, "/analysis/guest/"
  end
end