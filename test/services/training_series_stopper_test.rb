require "test_helper"

class TrainingSeriesStopperTest < ActiveSupport::TestCase
  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
  end

  test "stops generation and records the reason without cancelling sessions" do
    scheduled = @series.training_sessions.where(status: "scheduled").count

    result = TrainingSeriesStopper.new(@series, reason: "Season finished", actor: users(:three)).call

    assert result.success?
    assert result.changed
    @series.reload
    assert @series.stopped?
    assert_equal "Season finished", @series.stopped_reason
    assert_not_nil @series.stopped_at
    assert_equal scheduled, @series.training_sessions.where(status: "scheduled").count
  end

  test "is idempotent" do
    TrainingSeriesStopper.new(@series, reason: "Season finished").call

    result = TrainingSeriesStopper.new(@series, reason: "Again").call

    assert result.success?
    refute result.changed
    assert_equal "Season finished", @series.reload.stopped_reason
  end

  test "an already stopped series is unchanged" do
    result = TrainingSeriesStopper.new(training_series(:stopped_series), reason: "Again").call

    assert result.success?
    refute result.changed
  end
end

class TrainingSeriesFutureCancellerTest < ActiveSupport::TestCase
  setup do
    @series = training_series(:monday_series)
    TrainingSeriesGenerator.new(@series).call
  end

  test "cancels only occurrences from the local boundary onward" do
    result = TrainingSeriesFutureCanceller.new(
      @series, from: Date.new(2026, 11, 16), reason: "Venue unavailable"
    ).call

    assert result.success?
    assert_equal 4, result.affected.size
    assert_equal %w[
      2026-11-16T07:00 2026-11-18T07:00 2026-11-23T07:00 2026-11-25T07:00
    ], result.affected.map(&:recurrence_key).sort

    @series.training_sessions.reload.each do |session|
      expected = session.recurrence_key >= "2026-11-16T07:00"
      assert_equal expected, session.cancelled?, session.recurrence_key
    end
  end

  test "requires a date and a reason" do
    missing_date = TrainingSeriesFutureCanceller.new(
      @series, from: nil, reason: "Reason"
    ).call
    assert_not missing_date.success?
    assert_includes missing_date.errors, "A start date is required"

    missing_reason = TrainingSeriesFutureCanceller.new(
      @series, from: Date.new(2026, 11, 16), reason: ""
    ).call
    assert_not missing_reason.success?
    assert_includes missing_reason.errors, "A cancellation reason is required"
  end

  test "returns an empty success when the boundary is after every occurrence" do
    result = TrainingSeriesFutureCanceller.new(
      @series, from: Date.new(2027, 1, 1), reason: "Nothing left"
    ).call

    assert result.success?
    assert_empty result.affected
  end
end
