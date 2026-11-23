require "test_helper"

# Per-message email delivery (IDENTITY-265). Each message produces exactly one
# email per side, internal messages never leave the app, and retries are safe.
class AnalysisRequestMessageEmailJobTest < ActiveJob::TestCase
  setup do
    @previous_recipients = ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"]
    ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"] = "crew@bvb.test"

    @request = AnalysisRequest.create!(
      title: "Serve review", guest_name: "Jane Guest", guest_email: "jane@example.com"
    )
    @message = @request.analysis_request_messages.create!(
      body: "Here is my question.", from_submitter: true
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

  test "emails the crew and records the delivery" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      AnalysisRequestMessageEmailJob.perform_now(@message.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "crew@bvb.test" ], mail.to
    assert_equal [ "jane@example.com" ], mail.reply_to
    assert @message.reload.emailed_at.present?
  end

  test "is idempotent across retries" do
    AnalysisRequestMessageEmailJob.perform_now(@message.id)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      AnalysisRequestMessageEmailJob.perform_now(@message.id)
    end
  end

  test "team messages go to the submitter" do
    reply = @request.analysis_request_messages.create!(
      body: "We will review it tomorrow."
    )

    AnalysisRequestMessageEmailJob.perform_now(reply.id)

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "jane@example.com" ], mail.to
    assert_includes mail.subject, "New message about your analysis request"
  end

  test "internal messages are never emailed" do
    internal = @request.analysis_request_messages.create!(
      body: "Internal note", internal: true
    )

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      AnalysisRequestMessageEmailJob.perform_now(internal.id)
    end

    assert_nil internal.reload.emailed_at
  end

  test "a team message with no submitter address is skipped" do
    @request.update_columns(guest_email: nil)
    reply = @request.analysis_request_messages.create!(
      body: "Anyone there?"
    )

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      AnalysisRequestMessageEmailJob.perform_now(reply.id)
    end
  end
end
