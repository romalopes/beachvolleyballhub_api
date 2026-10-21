require "test_helper"

class TrainingSeriesDeleterTest < ActiveSupport::TestCase
  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
    @draft = @series.training_sessions.find_by(recurrence_key: "2026-11-02T07:00")
    @draft.update!(status: "draft")
  end

  test "deletes an unused draft occurrence" do
    assert_difference -> { TrainingSession.count }, -1 do
      result = TrainingSeriesDeleter.new(@series, session_ids: [ @draft.id ]).call

      assert result.success?
      assert_equal [ @draft.id ], result.deleted_ids
    end
  end

  test "refuses a scheduled occurrence" do
    scheduled = @series.training_sessions.find_by(recurrence_key: "2026-11-04T07:00")

    assert_no_difference -> { TrainingSession.count } do
      result = TrainingSeriesDeleter.new(@series, session_ids: [ scheduled.id ]).call

      assert result.success?
      assert_empty result.deleted_ids
      assert_equal [ { id: scheduled.id, reason: "not_a_draft" } ], result.skipped
    end
  end

  test "refuses a draft that has participants" do
    TrainingSessionParticipant.create!(
      training_session: @draft, player_profile: player_profiles(:john_player), status: "invited"
    )

    assert_no_difference -> { TrainingSession.count } do
      result = TrainingSeriesDeleter.new(@series, session_ids: [ @draft.id ]).call

      assert_equal [ { id: @draft.id, reason: "has_participants_or_assessments" } ],
                   result.skipped
    end
  end

  test "reports ids from another series without touching them" do
    foreign = training_sessions(:two)

    result = TrainingSeriesDeleter.new(@series, session_ids: [ foreign.id ]).call

    assert_empty result.deleted_ids
    assert_equal [ { id: foreign.id, reason: "not_in_series" } ], result.skipped
    assert TrainingSession.exists?(foreign.id)
  end

  test "requires at least one id" do
    result = TrainingSeriesDeleter.new(@series, session_ids: []).call

    assert_not result.success?
    assert_includes result.errors, "Select at least one occurrence"
  end
end
