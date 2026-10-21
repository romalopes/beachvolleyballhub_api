require "test_helper"

class TrainingSeriesSplitterTest < ActiveSupport::TestCase
  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
  end

  test "splits the series at the boundary and generates the new rule" do
    result = TrainingSeriesSplitter.new(
      @series,
      from: Date.new(2026, 11, 16),
      attributes: { weekdays: %w[thu], local_start_time: "18:00", ends_on: "2026-12-31" },
      reason: "Winter schedule",
      actor: users(:three)
    ).call

    assert result.success?, result.errors.inspect
    old = result.old_series.reload
    assert_equal Date.new(2026, 11, 15), old.ends_on
    assert old.stopped?
    assert_equal "Winter schedule", old.stopped_reason
    assert_equal 4, old.training_sessions.count
    assert_equal Date.new(2026, 11, 15), old.generated_through
    assert_equal 4, result.destroyed_count

    new_series = result.new_series.reload
    assert_equal Date.new(2026, 11, 16), new_series.starts_on
    assert_equal %w[thu], new_series.weekdays
    assert_equal "18:00", new_series.local_start_time.strftime("%H:%M")
    assert_equal users(:three), new_series.created_by
    assert_equal "Monday Skills", new_series.defaults[:title]
    assert_equal "2026-11-19T18:00",
                 new_series.training_sessions.order(:starts_at).first.recurrence_key
    assert_equal result.generator_result.created_count, new_series.training_sessions.count
  end

  test "refuses to split when a future occurrence has participants" do
    future = @series.training_sessions.find_by(recurrence_key: "2026-11-16T07:00")
    TrainingSessionParticipant.create!(
      training_session: future, player_profile: player_profiles(:john_player), status: "confirmed"
    )

    result = TrainingSeriesSplitter.new(
      @series, from: Date.new(2026, 11, 16),
      attributes: { weekdays: %w[thu] }, reason: "Winter schedule"
    ).call

    assert_not result.success?
    assert_includes result.errors, "Some future occurrences have participants, assessments or overrides"
    blocker = result.blockers.find { |row| row[:id] == future.id }
    assert_includes blocker[:reasons], "has_participants"

    assert_equal Date.new(2026, 11, 29), @series.reload.ends_on
    assert future.reload.scheduled?
    assert TrainingSession.exists?(future.id)
  end

  test "refuses overridden future occurrences unless discarding is explicit" do
    future = @series.training_sessions.find_by(recurrence_key: "2026-11-16T07:00")
    future.update!(override_fields: { "title" => true })

    refused = TrainingSeriesSplitter.new(
      @series, from: Date.new(2026, 11, 16),
      attributes: { weekdays: %w[thu] }, reason: "Winter schedule"
    ).call

    assert_not refused.success?
    assert_equal "overridden",
                 refused.blockers.find { |row| row[:id] == future.id }[:reasons].first

    allowed = TrainingSeriesSplitter.new(
      @series, from: Date.new(2026, 11, 16),
      attributes: { weekdays: %w[thu] }, reason: "Winter schedule",
      discard_overrides: true
    ).call

    assert allowed.success?, allowed.errors.inspect
    refute TrainingSession.exists?(future.id)
  end

  test "validates the boundary and the reason" do
    no_reason = TrainingSeriesSplitter.new(
      @series, from: Date.new(2026, 11, 16), attributes: { weekdays: %w[thu] }, reason: ""
    ).call
    assert_includes no_reason.errors, "A split reason is required"

    outside = TrainingSeriesSplitter.new(
      @series, from: Date.new(2026, 12, 1), attributes: { weekdays: %w[thu] }, reason: "Later"
    ).call
    assert_includes outside.errors,
                    "The split date must fall after the series start and on or before its end"
  end
end
