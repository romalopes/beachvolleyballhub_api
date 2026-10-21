require "test_helper"

class TrainingSeriesCancellerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
    @session = @series.training_sessions.find_by(recurrence_key: "2026-11-02T07:00")
    @other = @series.training_sessions.find_by(recurrence_key: "2026-11-04T07:00")
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  test "cancels selected scheduled occurrences and keeps the tombstone key" do
    result = TrainingSeriesCanceller.new(
      @series, session_ids: [ @session.id ], reason: "Storm", actor: users(:three)
    ).call

    assert result.success?
    assert_equal [ @session.id ], result.affected_ids
    @session.reload
    assert @session.cancelled?
    assert_equal "Storm", @session.cancellation_reason
    assert_equal users(:three), @session.cancelled_by
    assert_equal "2026-11-02T07:00", @session.recurrence_key
    assert @other.reload.scheduled?
  end

  test "skips completed, already cancelled and foreign ids" do
    @session.update!(status: "completed")
    already = @other
    already.mark_cancelled!(reason: "Earlier")

    result = TrainingSeriesCanceller.new(
      @series,
      session_ids: [ @session.id, already.id, training_sessions(:one).id ],
      reason: "Weather"
    ).call

    assert result.success?
    assert_empty result.affected
    assert_equal 3, result.skipped.size
    reasons = result.skipped.map { |row| row[:reason] }
    assert_includes reasons, "not_cancellable"
    assert_includes reasons, "already_cancelled"
    assert_includes reasons, "not_in_series"
    assert training_sessions(:one).reload.scheduled?
  end

  test "requires at least one id and a reason" do
    result = TrainingSeriesCanceller.new(@series, session_ids: [], reason: "").call

    assert_not result.success?
    assert_includes result.errors, "Select at least one occurrence"
    assert_includes result.errors, "A cancellation reason is required"
  end

  test "does not notify by default" do
    participant = TrainingSessionParticipant.create!(
      training_session: @session, player_profile: player_profiles(:john_player), status: "confirmed"
    )

    assert_no_enqueued_jobs do
      TrainingSeriesCanceller.new(
        @series, session_ids: [ @session.id ], reason: "Storm"
      ).call
    end

    assert_nil participant.reload.cancellation_notified_at
  end

  test "enqueues one cancellation email per reachable participant when requested" do
    participant = TrainingSessionParticipant.create!(
      training_session: @session, player_profile: player_profiles(:john_player), status: "confirmed"
    )
    TrainingSessionParticipant.create!(
      training_session: @session, player_profile: player_profiles(:pedro_player), status: "invited"
    )

    assert_enqueued_jobs 1 do
      TrainingSeriesCanceller.new(
        @series, session_ids: [ @session.id ], reason: "Storm",
        notify_participants: true
      ).call
    end

    assert_nil participant.reload.cancellation_notified_at
  end
end
