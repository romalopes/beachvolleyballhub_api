require "test_helper"

class TrainingRecurrenceExpanderTest < ActiveSupport::TestCase
  test "expands a multi-weekday weekly series inclusively" do
    result = expand(training_series(:monday_series))

    assert result.success?
    assert_equal %w[
      2026-11-02T07:00 2026-11-04T07:00 2026-11-09T07:00 2026-11-11T07:00
      2026-11-16T07:00 2026-11-18T07:00 2026-11-23T07:00 2026-11-25T07:00
    ], result.occurrences.map(&:recurrence_key)
  end

  test "converts the local wall clock to UTC in the series zone" do
    occurrence = expand(training_series(:monday_series)).occurrences.first

    # 07:00 in Sydney during daylight saving is 20:00 UTC the previous day.
    assert_equal "2026-11-01 20:00", occurrence.starts_at.utc.strftime("%Y-%m-%d %H:%M")
    assert_equal 7, occurrence.starts_at.in_time_zone("Australia/Sydney").hour
    assert_equal 90, ((occurrence.ends_at - occurrence.starts_at) / 60).round
  end

  test "includes the end date when it is a training day" do
    series = build_series(starts_on: Date.new(2026, 11, 30), ends_on: Date.new(2026, 11, 30),
                          weekdays: %w[mon])

    result = expand(series)

    assert result.success?
    assert_equal [ "2026-11-30T07:00" ], result.occurrences.map(&:recurrence_key)
  end

  test "honours a two-week interval anchored on the starting week" do
    series = build_series(interval: 2, weekdays: %w[mon])

    result = expand(series)

    assert_equal %w[2026-11-02T07:00 2026-11-16T07:00],
                 result.occurrences.map(&:recurrence_key)
  end

  test "a window limits the returned occurrences without shifting the anchor" do
    result = expand(training_series(:monday_series),
                    from: Date.new(2026, 11, 10), through: Date.new(2026, 11, 20))

    assert_equal %w[2026-11-11T07:00 2026-11-16T07:00 2026-11-18T07:00],
                 result.occurrences.map(&:recurrence_key)
  end

  test "returns nothing when the window is outside the series" do
    result = expand(training_series(:monday_series),
                    from: Date.new(2026, 12, 1), through: Date.new(2026, 12, 31))

    assert result.success?
    assert_empty result.occurrences
  end

  test "rejects a window longer than a year" do
    series = build_series(starts_on: Date.new(2020, 1, 1), ends_on: Date.new(2026, 12, 31))

    result = expand(series)

    assert_not result.success?
    assert_match(/cannot exceed 366 days/, result.errors.first)
  end

  test "rejects more than 200 occurrences" do
    series = build_series(starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31),
                          weekdays: TrainingSeries::WEEKDAYS)

    result = expand(series)

    assert_not result.success?
    assert_match(/maximum is 200/, result.errors.first)
  end

  test "reports a non-existent local time at the spring-forward boundary" do
    series = build_series(starts_on: Date.new(2026, 10, 4), ends_on: Date.new(2026, 10, 4),
                          weekdays: %w[sun], local_start_time: "02:30")

    result = expand(series)

    assert_not result.success?
    assert_match(/does not exist/, result.errors.first)
    assert_match(/2026-10-04/, result.errors.first)
  end

  test "resolves an ambiguous local time to the earlier instant and warns" do
    series = build_series(starts_on: Date.new(2026, 4, 5), ends_on: Date.new(2026, 4, 5),
                          weekdays: %w[sun], local_start_time: "02:30")

    result = expand(series)

    assert result.success?
    assert_equal 1, result.occurrences.size
    assert_match(/ambiguous/, result.warnings.first)

    occurrence = result.occurrences.first
    # 02:30 exists at +11:00 and +10:00; the earlier instant is +11:00.
    assert_equal "2026-04-04 15:30", occurrence.starts_at.utc.strftime("%Y-%m-%d %H:%M")
  end

  test "invalid series return validation errors instead of occurrences" do
    series = build_series(weekdays: [])

    result = expand(series)

    assert_not result.success?
    assert_includes result.errors, "Weekdays must include at least one weekday"
    assert_empty result.occurrences
  end

  test "a single-day series has a stable recurrence key" do
    series = build_series(starts_on: Date.new(2026, 11, 2), ends_on: Date.new(2026, 11, 2),
                          weekdays: %w[mon])

    occurrence = expand(series).occurrences.first

    assert_equal "2026-11-02T07:00", occurrence.recurrence_key
    assert_equal Date.new(2026, 11, 2), occurrence.local_date
  end

  private

  def expand(series, **options)
    TrainingRecurrenceExpander.new(series, **options).call
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
