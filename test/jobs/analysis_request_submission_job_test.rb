require "test_helper"

# Delivery of the two submission emails (IDENTITY-265).
#
# The job must reach both audiences, record each channel independently, and be
# safe to retry without double-sending.
class AnalysisRequestSubmissionJobTest < ActiveJob::TestCase
  setup do
    @previous_recipients = ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"]
    ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"] = "crew@bvb.test"

    @request = AnalysisRequest.create!(
      title: "Serve review",
      guest_name: "Jane Guest",
      guest_email: "jane@example.com"
    )
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    if @previous_recipients.nil?
      ENV.delete("ANALYSIS_REQUEST_NOTIFICATION_EMAILS")
    else
      ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"] = @previous_recipients
    end
  end

  test "delivers one email to the crew and one to the submitter" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
      AnalysisRequestSubmissionJob.perform_now(@request)
    end

    recipients = ActionMailer::Base.deliveries.map { |mail| mail.to }.flatten.sort
    assert_equal [ "crew@bvb.test", "jane@example.com" ].sort, recipients

    @request.reload
    assert @request.crew_emailed_at.present?
    assert @request.submitter_emailed_at.present?
  end

  test "is idempotent across retries" do
    AnalysisRequestSubmissionJob.perform_now(@request)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      AnalysisRequestSubmissionJob.perform_now(@request)
    end
  end

  test "still confirms to the submitter when no crew recipients exist" do
    # No env list and no admin/curator accounts with an address: the crew
    # channel is skipped, the submitter is still confirmed.
    ENV.delete("ANALYSIS_REQUEST_NOTIFICATION_EMAILS")
    UserRole.joins(:role).where(roles: { name: %w[admin curator] }).destroy_all

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      AnalysisRequestSubmissionJob.perform_now(@request)
    end

    @request.reload
    assert_nil @request.crew_emailed_at
    assert @request.submitter_emailed_at.present?
  end
end