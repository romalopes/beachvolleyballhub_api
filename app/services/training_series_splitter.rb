# Splits a series at a local boundary: the old series ends the day before, a
# new series with the changed recurrence starts on the boundary.
#
# Existing future occurrences of the old series are removed **only** when they
# carry no participants, assessments or overrides. Anything that has history is
# reported as a blocker and nothing is changed, so a split can never destroy
# somebody's registration silently.
class TrainingSeriesSplitter
  Result = Struct.new(:old_series, :new_series, :destroyed_count,
                      :generator_result, :errors, :blockers, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(series, from:, attributes:, reason:, actor: nil, discard_overrides: false)
    @series = series
    @from = from
    @attributes = (attributes.respond_to?(:to_h) ? attributes.to_h : {}).symbolize_keys
    @reason = reason.to_s.strip.presence
    @actor = actor
    @discard_overrides = discard_overrides
  end

  def call
    return failure([ "A split date is required" ]) if from.blank?
    return failure([ "A split reason is required" ]) if reason.blank?
    unless from.is_a?(Date) && from > series.starts_on && from <= series.ends_on
      return failure([ "The split date must fall after the series start and on or before its end" ])
    end

    errors = []
    blockers = []
    destroyed_count = 0
    new_series = nil
    generator_result = nil

    ActiveRecord::Base.transaction do
      series.lock!

      blockers = blocking_sessions
      if blockers.any?
        errors << "Some future occurrences have participants, assessments or overrides"
        raise ActiveRecord::Rollback
      end

      new_series = build_new_series
      unless new_series.valid?
        errors.concat(new_series.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      destroyed_sessions = future_eligible_sessions.to_a
      destroyed_sessions.each(&:destroy!)
      destroyed_count = destroyed_sessions.size

      series.update!(
        ends_on: from - 1.day,
        status: "stopped",
        stopped_at: Time.current,
        stopped_reason: reason,
        generated_through: [ series.generated_through, from - 1.day ].compact.min
      )

      new_series.save!
      generator_result = TrainingSeriesGenerator.new(new_series).call
      unless generator_result.success?
        errors.concat(generator_result.errors)
        raise ActiveRecord::Rollback
      end
    end

    if errors.any?
      failure(errors, blockers: blockers)
    else
      Result.new(old_series: series.reload, new_series: new_series,
                 destroyed_count: destroyed_count, generator_result: generator_result,
                 errors: [], blockers: [])
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  attr_reader :series, :from, :attributes, :reason, :actor, :discard_overrides

  def boundary
    series.time_zone_object.parse(from.iso8601)
  end

  def future_sessions
    series.training_sessions
          .includes(:training_session_participants, :assessments)
          .where(status: %w[draft scheduled])
          .where("starts_at >= ?", boundary)
  end

  def future_eligible_sessions
    future_sessions
  end

  def blocking_sessions
    future_sessions.filter_map do |session|
      reasons = []
      reasons << "has_participants" if session.training_session_participants.any?
      reasons << "has_assessments" if session.assessments.any?
      reasons << "overridden" if !discard_overrides && session.overridden?
      next if reasons.empty?

      { id: session.id, reasons: reasons }
    end
  end

  def build_new_series
    overrides = (attributes[:overrides] || {}).to_h.symbolize_keys
                                                .slice(*TrainingSeriesCreator::OVERRIDABLE_DEFAULTS)

    TrainingSeries.new(
      training_template: series.training_template,
      organisation: series.organisation,
      created_by: actor || series.created_by,
      frequency: "weekly",
      interval: attributes[:interval].presence || series.interval,
      weekdays: attributes[:weekdays].presence || series.weekdays,
      starts_on: from,
      ends_on: attributes[:ends_on].presence || series.ends_on,
      local_start_time: attributes[:local_start_time].presence || series.local_start_time,
      duration_minutes: attributes[:duration_minutes].presence || series.duration_minutes,
      time_zone: attributes[:time_zone].presence || series.time_zone,
      status: "active",
      defaults_snapshot: series.defaults.merge(overrides)
    )
  end

  def failure(messages, blockers: [])
    Result.new(old_series: nil, new_series: nil, destroyed_count: 0,
               generator_result: nil, errors: Array(messages), blockers: blockers)
  end
end
