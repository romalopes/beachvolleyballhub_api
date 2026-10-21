# Applies a set of field changes to future scheduled occurrences of a series.
#
# Occurrences that already diverge from the series defaults keep their values
# unless the caller explicitly asks to overwrite overrides. The series' defaults
# snapshot is updated too, so occurrences generated later inherit the change.
class TrainingSeriesFutureEditor
  ALLOWED_FIELDS = %w[
    title description location location_detail level capacity
    coach_profile_id group_id visibility
  ].freeze

  Result = Struct.new(:updated_ids, :skipped, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(series, from:, changes:, overwrite_overrides: false, actor: nil)
    @series = series
    @from = from
    @changes = sanitize_changes(changes)
    @overwrite_overrides = overwrite_overrides
    @actor = actor
  end

  def call
    return Result.new(updated_ids: [], skipped: [], errors: [ "A start date is required" ]) if from.blank?
    return Result.new(updated_ids: [], skipped: [], errors: [ "Choose at least one field to change" ]) if changes.empty?

    updated_ids = []
    skipped = []
    errors = []
    rolled_back = false

    ActiveRecord::Base.transaction do
      sessions = series.training_sessions
                       .where(status: "scheduled")
                       .where("starts_at >= ?", boundary)
                       .to_a

      sessions.each do |session|
        applicable = changes.reject do |field, _value|
          !overwrite_overrides && session.overridden_field?(field)
        end

        if applicable.empty?
          skipped << { id: session.id, reason: "all_fields_overridden" }
          next
        end

        session.assign_attributes(applicable)
        session.override_fields = session.override_fields.merge(
          applicable.keys.index_with { true }
        )

        if session.save
          updated_ids << session.id
        else
          errors.concat(session.errors.full_messages)
        end
      end

      if errors.any?
        rolled_back = true
        raise ActiveRecord::Rollback
      end

      series.update!(
        defaults_snapshot: series.defaults.merge(changes.symbolize_keys)
      )
    end

    updated_ids = [] if rolled_back

    Result.new(updated_ids: updated_ids, skipped: skipped, errors: errors)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(updated_ids: [], skipped: [], errors: e.record.errors.full_messages)
  end

  private

  attr_reader :series, :from, :changes, :overwrite_overrides, :actor

  def sanitize_changes(raw)
    data = raw.respond_to?(:to_h) ? raw.to_h : {}
    data.stringify_keys.slice(*ALLOWED_FIELDS)
  end

  def boundary
    series.time_zone_object.parse(from.iso8601)
  end
end
