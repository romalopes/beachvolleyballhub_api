require "test_helper"

class TrainingSeriesPreviewTest < ActiveSupport::TestCase
  test "previews without writing and reports the total" do
    payload = nil

    assert_no_difference -> { TrainingSession.count } do
      payload = preview(training_series(:monday_series))
    end

    assert payload[:valid]
    assert_equal 8, payload[:total]
    assert_equal 8, payload[:returned]
    refute payload[:truncated]
    assert_equal "Australia/Sydney", payload[:time_zone]
    assert_equal "2026-11-02T07:00", payload[:occurrences].first[:recurrence_key]
    assert_equal "2026-11-02", payload[:occurrences].first[:local_date]
    assert_equal 90, payload[:occurrences].first[:duration_minutes]
  end

  test "truncates long previews while reporting the full total" do
    series = build_series(starts_on: Date.new(2026, 1, 5), ends_on: Date.new(2026, 6, 30),
                          weekdays: %w[mon wed fri], time_zone: "UTC")

    payload = preview(series)

    assert payload[:valid]
    assert payload[:truncated]
    assert_equal TrainingSeriesPreview::PREVIEW_LIMIT, payload[:returned]
    assert_operator payload[:total], :>, TrainingSeriesPreview::PREVIEW_LIMIT
  end

  test "reports a coach overlap with an existing scheduled session" do
    conflicting = TrainingSession.create!(
      title: "Existing coach booking",
      starts_at: Time.utc(2026, 11, 1, 20, 0),
      ends_at: Time.utc(2026, 11, 1, 21, 0),
      status: "scheduled",
      coach_profile: coach_profiles(:maria_coach)
    )

    payload = preview(training_series(:monday_series))
    occurrence = payload[:occurrences].find { |o| o[:recurrence_key] == "2026-11-02T07:00" }

    conflict = occurrence[:conflicts].find { |c| c[:id] == conflicting.id }
    assert_not_nil conflict
    assert_includes conflict[:reasons], "coach_overlap"
  end

  test "reports a location overlap only when the location matches" do
    conflicting = TrainingSession.create!(
      title: "Existing court booking",
      starts_at: Time.utc(2026, 11, 3, 20, 0),
      ends_at: Time.utc(2026, 11, 3, 21, 0),
      location: "Coogee Beach",
      status: "scheduled"
    )

    payload = preview(training_series(:monday_series))
    occurrence = payload[:occurrences].find { |o| o[:recurrence_key] == "2026-11-04T07:00" }

    conflict = occurrence[:conflicts].find { |c| c[:id] == conflicting.id }
    assert_not_nil conflict
    assert_includes conflict[:reasons], "location_overlap"
  end

  test "ignores cancelled sessions as conflicts" do
    TrainingSession.create!(
      title: "Cancelled booking",
      starts_at: Time.utc(2026, 11, 1, 20, 0),
      ends_at: Time.utc(2026, 11, 1, 21, 0),
      status: "cancelled",
      coach_profile: coach_profiles(:maria_coach)
    )

    payload = preview(training_series(:monday_series))

    assert payload[:occurrences].all? { |occurrence| occurrence[:conflicts].empty? }
  end

  test "surfaces series validation errors" do
    payload = preview(build_series(weekdays: []))

    assert_not payload[:valid]
    assert_includes payload[:errors], "Weekdays must include at least one weekday"
    assert_empty payload[:occurrences]
    assert_equal 0, payload[:total]
  end

  test "surfaces DST errors from the expander" do
    series = build_series(starts_on: Date.new(2026, 10, 4), ends_on: Date.new(2026, 10, 4),
                          weekdays: %w[sun], local_start_time: "02:30")

    payload = preview(series)

    assert_not payload[:valid]
    assert_match(/does not exist/, payload[:errors].first)
  end

  private

  def preview(series)
    TrainingSeriesPreview.new(template: series.training_template, series: series).call
  end

  def build_series(overrides = {})
    TrainingSeries.new({
      training_template: training_templates(:monday_skills),
      organisation: organisations(:sydney_club),
      created_by: users(:three),
      frequency: "weekly",
      interval: 1,
      weekdays: %w[mon wed],
      starts_on: Date.new(2026, 11, 2),
      ends_on: Date.new(2026, 11, 29),
      local_start_time: "07:00",
      duration_minutes: 90,
      time_zone: "Australia/Sydney",
      status: "active",
      defaults_snapshot: {}
    }.merge(overrides))
  end
end
