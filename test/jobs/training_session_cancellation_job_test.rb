require "test_helper"

class TrainingSessionCancellationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
    @session = @series.training_sessions.find_by(recurrence_key: "2026-11-02T07:00")

    @john = TrainingSessionParticipant.create!(
      training_session: @session, player_profile: player_profiles(:john_player), status: "confirmed"
    )
    @pedro = TrainingSessionParticipant.create!(
      training_session: @session, player_profile: player_profiles(:pedro_player), status: "invited"
    )

    @session.mark_cancelled!(reason: "Storm warning")

    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  test "delivers one cancellation email and marks the participant" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      TrainingSessionCancellationJob.perform_now(@john.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ users(:five).email_address ], mail.to
    assert_includes mail.subject, "Training cancelled"
    assert_includes mail.subject, @session.title

    body = mail.text_part&.body.to_s + mail.html_part&.body.to_s
    assert_includes body, "Storm warning"
    assert_includes body, "Australia/Sydney"

    assert_not_nil @john.reload.cancellation_notified_at
  end

  test "is idempotent on retry" do
    TrainingSessionCancellationJob.perform_now(@john.id)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      TrainingSessionCancellationJob.perform_now(@john.id)
    end
  end

  test "does not email a participant without an account" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      TrainingSessionCancellationJob.perform_now(@pedro.id)
    end

    assert_nil @pedro.reload.cancellation_notified_at
  end

  test "does nothing for a session that is not cancelled" do
    @session.update!(status: "scheduled")
    @john.update!(cancellation_notified_at: nil)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      TrainingSessionCancellationJob.perform_now(@john.id)
    end
  end

  test "ignores an unknown participant" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      TrainingSessionCancellationJob.perform_now(-1)
    end
  end

  test "the notifier enqueues only reachable participants" do
    @john.update!(cancellation_notified_at: nil)

    assert_enqueued_jobs 1 do
      TrainingSessionCancellationNotifier.call([ @session ])
    end
  end
end
