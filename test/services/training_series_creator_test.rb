require "test_helper"

class TrainingSeriesCreatorTest < ActiveSupport::TestCase
  test "creates the series and its occurrences from a template" do
    result = TrainingSeriesCreator.call(
      template: training_templates(:monday_skills),
      attributes: recurrence_attributes,
      actor: users(:three)
    )

    assert result.success?
    series = result.series
    assert series.persisted?
    assert_equal training_templates(:monday_skills), series.training_template
    assert_equal organisations(:sydney_club), series.organisation
    assert_equal users(:three), series.created_by
    assert_equal 8, result.generator_result.created_count
    assert_equal 8, series.training_sessions.count
  end

  test "snapshots overrides without mutating the template" do
    result = TrainingSeriesCreator.call(
      template: training_templates(:monday_skills),
      attributes: recurrence_attributes(
        overrides: { title: "Sunrise Skills", capacity: 16, location: "Bondi Beach" }
      ),
      actor: users(:three)
    )

    assert result.success?
    series = result.series
    assert_equal "Sunrise Skills", series.defaults[:title]
    assert_equal 16, series.defaults[:capacity]
    assert_equal "Bondi Beach", series.defaults[:location]

    session = series.training_sessions.first
    assert_equal "Sunrise Skills", session.title
    assert_equal 16, session.capacity
    assert_equal "Bondi Beach", session.location

    template = training_templates(:monday_skills).reload
    assert_equal "Monday Skills", template.name
    assert_equal 12, template.capacity
  end

  test "falls back to template defaults and the application time zone" do
    attributes = recurrence_attributes
    attributes.delete(:time_zone)
    attributes.delete(:duration_minutes)

    result = TrainingSeriesCreator.call(
      template: training_templates(:monday_skills),
      attributes: attributes,
      actor: users(:three)
    )

    assert result.success?
    assert_equal "UTC", result.series.time_zone
    assert_equal 90, result.series.duration_minutes
    assert_equal "Coogee Beach", result.series.training_sessions.first.location
  end

  test "rejects an invalid recurrence without writing" do
    assert_no_difference -> { TrainingSeries.count } do
      assert_no_difference -> { TrainingSession.count } do
        result = TrainingSeriesCreator.call(
          template: training_templates(:monday_skills),
          attributes: recurrence_attributes(weekdays: []),
          actor: users(:three)
        )

        assert_not result.success?
        assert_includes result.errors, "Weekdays must include at least one weekday"
        assert_nil result.series
      end
    end
  end

  test "rolls the series back when occurrence generation fails" do
    assert_no_difference -> { TrainingSeries.count } do
      assert_no_difference -> { TrainingSession.count } do
        result = TrainingSeriesCreator.call(
          template: training_templates(:monday_skills),
          attributes: recurrence_attributes(overrides: { capacity: 0 }),
          actor: users(:three)
        )

        assert_not result.success?
        assert_includes result.errors, "Capacity must be greater than 0"
        assert_nil result.series
      end
    end
  end

  test "build_series returns an unsaved series for preview" do
    series = TrainingSeriesCreator.build_series(
      template: training_templates(:monday_skills),
      attributes: recurrence_attributes(overrides: { title: "Preview me" }),
      actor: users(:three)
    )

    assert series.new_record?
    assert series.valid?
    assert_equal "Preview me", series.defaults[:title]
  end

  test "drops unknown override keys" do
    series = TrainingSeriesCreator.build_series(
      template: training_templates(:monday_skills),
      attributes: recurrence_attributes(overrides: { title: "Kept", nonsense: "dropped" }),
      actor: users(:three)
    )

    assert_equal "Kept", series.defaults[:title]
    refute series.defaults.key?(:nonsense)
  end

  private

  def recurrence_attributes(overrides = {})
    {
      starts_on: Date.new(2026, 11, 2),
      ends_on: Date.new(2026, 11, 29),
      weekdays: %w[mon wed],
      local_start_time: "07:00",
      duration_minutes: 90,
      time_zone: "Australia/Sydney",
      frequency: "weekly",
      interval: 1,
      overrides: {}
    }.merge(overrides)
  end
end
