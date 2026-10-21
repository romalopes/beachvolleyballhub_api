# Persists the occurrences a TrainingSeries describes.
#
# Idempotency is the central property: a session is identified by
# `(training_series_id, recurrence_key)`, so running the generator twice (or two
# requests racing) can never create a duplicate. Cancelled occurrences keep
# their key, which makes them tombstones: the generator reports them as
# `already_present` instead of resurrecting them.
#
# By default generation is atomic: if any occurrence fails validation the whole
# run is rolled back and `generated_through` is not advanced. Callers that need
# partial results can pass `atomic: false`; in that case `generated_through`
# also stays put so a retry revisits the failed occurrences.
class TrainingSeriesGenerator
  Result = Struct.new(:created, :already_present, :errors, :occurrences,
                      :window_start, :window_end, keyword_init: true) do
    def success?
      errors.empty?
    end

    def created_count
      created.size
    end
  end

  def initialize(series, atomic: true)
    @series = series
    @atomic = atomic
  end

  def call(from: nil, through: nil)
    result = expander(from: from, through: through).call
    return empty_result(result.errors) unless result.success?

    occurrences = result.occurrences
    window_end = [ through || series.ends_on, series.ends_on ].compact.min
    return empty_result([], occurrences: [], window_end: window_end) if occurrences.empty?

    created = []
    already_present = []
    errors = []
    rolled_back = false

    ActiveRecord::Base.transaction do
      series.lock!
      existing_keys = existing_recurrence_keys(occurrences)

      occurrences.each do |occurrence|
        if existing_keys.include?(occurrence.recurrence_key)
          already_present << occurrence.recurrence_key
          next
        end

        session = TrainingSession.new(attributes_for(occurrence))
        begin
          session.save!
          created << session
        rescue ActiveRecord::RecordNotUnique
          # A concurrent generator won the race; the unique index is the truth.
          already_present << occurrence.recurrence_key
        rescue ActiveRecord::RecordInvalid => e
          errors.concat(e.record.errors.full_messages)
        end
      end

      if errors.any? && atomic
        rolled_back = true
        raise ActiveRecord::Rollback
      end

      if errors.empty?
        series.update!(generated_through: window_end, last_generated_at: Time.current)
      end
    end

    if rolled_back
      created = []
      already_present = []
    end

    Result.new(created: created, already_present: already_present, errors: errors,
               occurrences: occurrences, window_start: occurrences.first.local_date,
               window_end: window_end)
  end

  private

  attr_reader :series, :atomic

  def expander(from:, through:)
    TrainingRecurrenceExpander.new(
      series,
      from: from || series.next_generation_start,
      through: through || series.ends_on
    )
  end

  def existing_recurrence_keys(occurrences)
    TrainingSession
      .where(training_series_id: series.id,
             recurrence_key: occurrences.map(&:recurrence_key))
      .pluck(:recurrence_key)
      .to_set
  end

  def attributes_for(occurrence)
    defaults = effective_defaults

    {
      title: defaults[:title].presence || series.training_template.name,
      description: defaults[:description],
      starts_at: occurrence.starts_at,
      ends_at: occurrence.ends_at,
      location: defaults[:location],
      location_detail: defaults[:location_detail],
      level: defaults[:level],
      capacity: defaults[:capacity],
      visibility: defaults[:visibility].presence || series.training_template.visibility,
      status: "scheduled",
      organisation_id: defaults[:organisation_id].presence || series.organisation_id,
      group_id: defaults[:group_id],
      coach_profile_id: defaults[:coach_profile_id],
      training_series: series,
      training_template: series.training_template,
      recurrence_key: occurrence.recurrence_key,
      original_starts_at: occurrence.starts_at,
      override_fields: {},
      created_by: series.created_by
    }
  end

  def effective_defaults
    @effective_defaults ||= series.training_template.defaults_for_series.merge(series.defaults)
  end

  def empty_result(errors, occurrences: [], window_end: nil)
    Result.new(created: [], already_present: [], errors: Array(errors),
               occurrences: occurrences, window_start: nil, window_end: window_end)
  end
end
