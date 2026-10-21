require "test_helper"

class TrainingSeriesGeneratorTest < ActiveSupport::TestCase
  test "creates every occurrence from the snapshotted defaults" do
    series = training_series(:monday_series)

    result = TrainingSeriesGenerator.new(series).call

    assert result.success?
    assert_equal 8, result.created_count
    assert_equal 8, series.training_sessions.count

    session = series.training_sessions.order(:starts_at).first
    assert_equal "Monday Skills", session.title
    assert_equal "Coogee Beach", session.location
    assert_equal "Court 1", session.location_detail
    assert_equal 12, session.capacity
    assert_equal 90, session.duration_minutes
    assert_equal "scheduled", session.status
    assert_equal "shared", session.visibility
    assert_equal series, session.training_series
    assert_equal training_templates(:monday_skills), session.training_template
    assert_equal organisations(:sydney_club), session.organisation
    assert_equal groups(:sydney_club_squad), session.group
    assert_equal coach_profiles(:maria_coach), session.coach_profile
    assert_equal users(:three), session.created_by
    assert_equal "2026-11-02T07:00", session.recurrence_key
    assert_equal session.starts_at, session.original_starts_at
    assert_empty session.override_fields
  end

  test "advances the generation horizon" do
    series = training_series(:monday_series)

    TrainingSeriesGenerator.new(series).call

    series.reload
    assert_equal Date.new(2026, 11, 29), series.generated_through
    assert_not_nil series.last_generated_at
  end

  test "is idempotent" do
    series = training_series(:monday_series)
    TrainingSeriesGenerator.new(series).call

    result = TrainingSeriesGenerator.new(series).call(
      from: series.starts_on, through: series.ends_on
    )

    assert result.success?
    assert_equal 0, result.created_count
    assert_equal 8, result.already_present.size
    assert_equal 8, series.training_sessions.count
  end

  test "never resurrects a cancelled occurrence" do
    series = training_series(:monday_series)
    TrainingSeriesGenerator.new(series).call
    cancelled = series.training_sessions.find_by(recurrence_key: "2026-11-04T07:00")
    cancelled.mark_cancelled!(reason: "Weather", actor: users(:three))

    result = TrainingSeriesGenerator.new(series).call(
      from: series.starts_on, through: series.ends_on
    )

    assert result.success?
    assert_equal 0, result.created_count
    assert_includes result.already_present, "2026-11-04T07:00"
    assert_equal 8, series.training_sessions.count
    assert cancelled.reload.cancelled?
  end

  test "generates a window in two runs without duplicates" do
    series = training_series(:monday_series)

    first = TrainingSeriesGenerator.new(series).call(
      from: Date.new(2026, 11, 1), through: Date.new(2026, 11, 10)
    )
    assert_equal 3, first.created_count
    assert_equal Date.new(2026, 11, 10), series.reload.generated_through

    second = TrainingSeriesGenerator.new(series).call(
      from: Date.new(2026, 11, 11), through: Date.new(2026, 11, 29)
    )
    assert_equal 5, second.created_count
    assert_equal 8, series.training_sessions.count
    assert_equal 8, series.training_sessions.distinct.count(:recurrence_key)
  end

  test "rolls everything back when an occurrence is invalid" do
    series = create_series_with_broken_defaults

    assert_no_difference -> { TrainingSession.count } do
      result = TrainingSeriesGenerator.new(series).call

      assert_not result.success?
      assert_includes result.errors, "Capacity must be greater than 0"
      assert_equal 0, result.created_count
    end

    assert_nil series.reload.generated_through
  end

  test "keeps partial results when atomic is false but does not advance the horizon" do
    series = create_series_with_broken_defaults

    result = TrainingSeriesGenerator.new(series, atomic: false).call

    assert_not result.success?
    refute_empty result.errors
    assert_nil series.reload.generated_through
  end

  test "does not touch sessions from other series" do
    other = TrainingSession.create!(
      title: "Manual session",
      starts_at: Time.zone.parse("2026-11-02 09:00"),
      ends_at: Time.zone.parse("2026-11-02 10:00"),
      status: "scheduled"
    )

    TrainingSeriesGenerator.new(training_series(:monday_series)).call

    assert other.reload.scheduled?
    assert_nil other.training_series_id
  end

  private

  def create_series_with_broken_defaults
    TrainingSeries.create!(
      training_template: training_templates(:monday_skills),
      organisation: organisations(:sydney_club),
      created_by: users(:three),
      frequency: "weekly",
      interval: 1,
      weekdays: %w[mon],
      starts_on: Date.new(2026, 11, 2),
      ends_on: Date.new(2026, 11, 9),
      local_start_time: "07:00",
      duration_minutes: 90,
      time_zone: "Australia/Sydney",
      status: "active",
      defaults_snapshot: { "title" => "Broken", "capacity" => 0 }
    )
  end
end
