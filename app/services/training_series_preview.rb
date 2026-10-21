# Dry-run a recurrence before anything is persisted.
#
# It reuses TrainingRecurrenceExpander (so preview dates and generated dates
# cannot drift), validates the same series object, and reports advisory
# conflicts with existing scheduled sessions (same coach or same location).
# It never writes.
class TrainingSeriesPreview
  PREVIEW_LIMIT = 60
  MAX_CONFLICTS_PER_OCCURRENCE = 5

  def initialize(template:, series:)
    @template = template
    @series = series
  end

  def call
    result = TrainingRecurrenceExpander.new(series).call
    occurrences = result.occurrences
    conflicts = result.success? ? conflicts_by_key(occurrences) : {}
    displayed = occurrences.first(PREVIEW_LIMIT)

    {
      valid: result.success?,
      errors: result.errors,
      warnings: result.warnings,
      time_zone: series.time_zone,
      total: occurrences.size,
      returned: displayed.size,
      truncated: occurrences.size > PREVIEW_LIMIT,
      occurrences: displayed.map { |occurrence| occurrence_payload(occurrence, conflicts) }
    }
  end

  private

  attr_reader :template, :series

  def effective_defaults
    @effective_defaults ||= template.defaults_for_series.merge(series.defaults)
  end

  def coach_profile_id
    effective_defaults[:coach_profile_id]
  end

  def location
    effective_defaults[:location].presence
  end

  def conflicts_by_key(occurrences)
    return {} if occurrences.empty? || (coach_profile_id.blank? && location.blank?)

    sessions = conflict_candidates(occurrences)
    return {} if sessions.empty?

    occurrences.each_with_object({}) do |occurrence, index|
      matches = sessions.select { |session| overlaps?(session, occurrence) }
      next if matches.empty?

      index[occurrence.recurrence_key] = matches.first(MAX_CONFLICTS_PER_OCCURRENCE)
                                               .map { |session| conflict_payload(session) }
    end
  end

  # One query for the whole preview window, then in-memory overlap checks.
  # Cancelled and completed sessions cannot conflict with a new schedule.
  def conflict_candidates(occurrences)
    conditions = []
    values = []

    if coach_profile_id.present?
      conditions << "coach_profile_id = ?"
      values << coach_profile_id
    end
    if location.present?
      conditions << "LOWER(location) = ?"
      values << location.downcase
    end
    return [] if conditions.empty?

    TrainingSession
      .where(status: %w[draft scheduled])
      .where("starts_at < ? AND ends_at > ?", occurrences.map(&:ends_at).max,
             occurrences.map(&:starts_at).min)
      .where(conditions.join(" OR "), *values)
      .to_a
  end

  def overlaps?(session, occurrence)
    session.starts_at < occurrence.ends_at && session.ends_at > occurrence.starts_at
  end

  def conflict_payload(session)
    reasons = []
    reasons << "coach_overlap" if coach_profile_id.present? &&
                                   session.coach_profile_id == coach_profile_id
    if location.present? && session.location.present? &&
       session.location.casecmp?(location)
      reasons << "location_overlap"
    end

    {
      id: session.id,
      title: session.title,
      status: session.status,
      starts_at: session.starts_at.iso8601,
      ends_at: session.ends_at.iso8601,
      location: session.location,
      reasons: reasons
    }
  end

  def occurrence_payload(occurrence, conflicts)
    {
      recurrence_key: occurrence.recurrence_key,
      local_date: occurrence.local_date.iso8601,
      local_start_time: format("%02d:%02d", series.local_start_time.hour,
                               series.local_start_time.min),
      starts_at: occurrence.starts_at.iso8601,
      ends_at: occurrence.ends_at.iso8601,
      duration_minutes: occurrence.duration_minutes,
      warnings: occurrence.warnings,
      conflicts: conflicts.fetch(occurrence.recurrence_key, [])
    }
  end
end
