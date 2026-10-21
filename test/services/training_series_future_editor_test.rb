require "test_helper"

class TrainingSeriesFutureEditorTest < ActiveSupport::TestCase
  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
    @first = @series.training_sessions.find_by(recurrence_key: "2026-11-02T07:00")
    @future = @series.training_sessions.find_by(recurrence_key: "2026-11-16T07:00")
  end

  test "edits future scheduled occurrences and the defaults snapshot" do
    result = TrainingSeriesFutureEditor.new(
      @series,
      from: Date.new(2026, 11, 16),
      changes: { title: "Sunset Skills", location: "Bondi Beach", capacity: 20 }
    ).call

    assert result.success?
    assert_equal 4, result.updated_ids.size
    assert_includes result.updated_ids, @future.id
    assert_not_includes result.updated_ids, @first.id

    @future.reload
    assert_equal "Sunset Skills", @future.title
    assert_equal "Bondi Beach", @future.location
    assert_equal 20, @future.capacity
    assert @future.overridden_field?(:title)
    assert @future.overridden_field?(:capacity)

    assert_equal "Sunset Skills", @series.reload.defaults[:title]
    assert_equal 20, @series.defaults[:capacity]

    assert_equal "Monday Skills", @first.reload.title
  end

  test "preserves an existing override unless explicitly overwritten" do
    @future.update!(title: "Coach's custom title",
                    override_fields: { "title" => true })

    result = TrainingSeriesFutureEditor.new(
      @series, from: Date.new(2026, 11, 16),
      changes: { title: "Series title", capacity: 18 }
    ).call

    assert result.success?
    @future.reload
    assert_equal "Coach's custom title", @future.title
    assert_equal 18, @future.capacity
  end

  test "overwrites overrides when asked" do
    @future.update!(title: "Coach's custom title",
                    override_fields: { "title" => true })

    result = TrainingSeriesFutureEditor.new(
      @series, from: Date.new(2026, 11, 16),
      changes: { title: "Series title" }, overwrite_overrides: true
    ).call

    assert result.success?
    assert_equal "Series title", @future.reload.title
  end

  test "skips occurrences when every requested field is overridden" do
    @series.training_sessions
           .where("starts_at >= ?", @series.time_zone_object.parse("2026-11-16"))
           .find_each do |session|
      session.update!(override_fields: { "title" => true })
    end

    result = TrainingSeriesFutureEditor.new(
      @series, from: Date.new(2026, 11, 16), changes: { title: "Series title" }
    ).call

    assert result.success?
    assert_empty result.updated_ids
    assert_equal 4, result.skipped.size
    assert(result.skipped.all? { |row| row[:reason] == "all_fields_overridden" })
  end

  test "rolls back on a validation error" do
    result = TrainingSeriesFutureEditor.new(
      @series, from: Date.new(2026, 11, 16), changes: { capacity: 0 }
    ).call

    assert_not result.success?
    assert_includes result.errors, "Capacity must be greater than 0"
    assert_empty result.updated_ids
    assert_equal 12, @future.reload.capacity
    assert_nil @series.reload.defaults[:capacity]
  end

  test "requires a date and at least one change" do
    no_date = TrainingSeriesFutureEditor.new(
      @series, from: nil, changes: { title: "x" }
    ).call
    assert_includes no_date.errors, "A start date is required"

    no_changes = TrainingSeriesFutureEditor.new(
      @series, from: Date.new(2026, 11, 16), changes: {}
    ).call
    assert_includes no_changes.errors, "Choose at least one field to change"
  end
end
