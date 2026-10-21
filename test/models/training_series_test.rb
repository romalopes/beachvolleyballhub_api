require "test_helper"

class TrainingSeriesTest < ActiveSupport::TestCase
  test "accepts a valid series" do
    assert training_series(:monday_series).valid?
  end

  test "normalises weekday tokens" do
    series = build_series(weekdays: [ "MON", " mon ", "", "Wed", "wed" ])

    assert series.valid?
    assert_equal %w[mon wed], series.weekdays
  end

  test "requires at least one weekday" do
    series = build_series(weekdays: [])

    assert_not series.valid?
    assert_includes series.errors.attribute_names, :weekdays
  end

  test "rejects unknown weekdays" do
    series = build_series(weekdays: %w[mon funday])

    assert_not series.valid?
    assert_includes series.errors.attribute_names, :weekdays
  end

  test "rejects an end date before the start date" do
    series = build_series(starts_on: Date.new(2026, 11, 10), ends_on: Date.new(2026, 11, 3))

    assert_not series.valid?
    assert_includes series.errors.attribute_names, :ends_on
  end

  test "requires a positive duration and a positive interval" do
    assert_not build_series(duration_minutes: 0).valid?
    assert_not build_series(interval: 0).valid?
  end

  test "accepts only weekly frequency" do
    assert build_series(frequency: "weekly").valid?

    series = build_series(frequency: "daily")
    assert_not series.valid?
    assert_includes series.errors.attribute_names, :frequency
  end

  test "accepts only known statuses" do
    assert build_series(status: "active").valid?
    assert build_series(status: "stopped").valid?

    series = build_series(status: "paused")
    assert_not series.valid?
    assert_includes series.errors.attribute_names, :status
  end

  test "requires a recognised IANA time zone" do
    assert build_series(time_zone: "Australia/Sydney").valid?
    assert build_series(time_zone: "UTC").valid?

    series = build_series(time_zone: "Mars/Olympus")
    assert_not series.valid?
    assert_includes series.errors.attribute_names, :time_zone
  end

  test "the organisation must match the template's organisation" do
    series = build_series(organisation: organisations(:northern_club))

    assert_not series.valid?
    assert_includes series.errors.attribute_names, :organisation
  end

  test "defaults returns the snapshot with symbol keys" do
    defaults = training_series(:monday_series).defaults

    assert_equal "Monday Skills", defaults[:title]
    assert_equal "Coogee Beach", defaults[:location]
  end

  test "next_generation_start is exclusive and never before starts_on" do
    series = build_series(generated_through: nil)
    assert_equal Date.new(2026, 11, 2), series.next_generation_start

    series.generated_through = Date.new(2026, 11, 10)
    assert_equal Date.new(2026, 11, 11), series.next_generation_start

    series.generated_through = Date.new(2026, 10, 1)
    assert_equal Date.new(2026, 11, 2), series.next_generation_start
  end

  test "completed? compares the end date with today" do
    travel_to Date.new(2026, 11, 30) do
      assert training_series(:monday_series).completed?
    end

    travel_to Date.new(2026, 11, 1) do
      refute training_series(:monday_series).completed?
    end
  end

  test "status predicates" do
    assert training_series(:monday_series).active?
    refute training_series(:monday_series).stopped?
    assert training_series(:stopped_series).stopped?
  end

  test "time_zone_object returns the ActiveSupport zone" do
    series = training_series(:monday_series)

    assert_equal "Australia/Sydney", series.time_zone_object.tzinfo.name
    assert_equal "UTC", training_series(:private_series).time_zone_object.name
  end

  test "a series with occurrences cannot be deleted" do
    assert_equal :restrict_with_error,
                 TrainingSeries.reflect_on_association(:training_sessions).options[:dependent]
  end

  private

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
      defaults_snapshot: { "title" => "Monday Skills" }
    }.merge(overrides))
  end
end
