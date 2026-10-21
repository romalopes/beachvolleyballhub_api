# Expands a TrainingSeries into concrete occurrences.
#
# This service is deliberately pure: it reads a (possibly unsaved) series and
# returns occurrence value objects without writing anything. Generation and
# preview both call it, so the dates a coach previews are exactly the dates that
# will be persisted.
#
# Weekly model
# ------------
# `weekdays` are local day tokens (mon..sun). `interval` counts weeks from the
# week containing `starts_on` (Monday-anchored): interval 2 means "every other
# week from the starting week". The end date is inclusive.
#
# Time model
# ----------
# `local_start_time` is a wall-clock time in `time_zone`. Each date is converted
# with TZInfo so DST is handled explicitly:
#   * a non-existent local time (spring-forward gap) is an error for that date;
#   * an ambiguous local time (fall-back overlap) resolves to the earlier
#     instant and emits a warning.
# `ends_at` is the start plus the elapsed duration, so a session crossing a DST
# boundary keeps its real length.
class TrainingRecurrenceExpander
  MAX_OCCURRENCES = 200
  MAX_SPAN_DAYS = 366
  WEEKDAY_NUMBERS = {
    "mon" => 1, "tue" => 2, "wed" => 3, "thu" => 4,
    "fri" => 5, "sat" => 6, "sun" => 7
  }.freeze

  Occurrence = Struct.new(:recurrence_key, :local_date, :starts_at, :ends_at,
                          :duration_minutes, :warnings, keyword_init: true)

  Result = Struct.new(:occurrences, :errors, :warnings, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(series, from: nil, through: nil)
    @series = series
    @from = from || series.starts_on
    @through = through || series.ends_on
  end

  def call
    return failure(series.errors.full_messages) unless series.valid?
    return failure([ span_message ]) if span_too_long?

    occurrences = []
    warnings = []
    duplicates = Hash.new(0)

    each_candidate_date do |date|
      time_result = resolve_local_start(date)
      if time_result[:error]
        return failure([ time_result[:error] ])
      end

      warnings.concat(time_result[:warnings])
      recurrence_key = recurrence_key_for(date)
      duplicates[recurrence_key] += 1

      occurrences << Occurrence.new(
        recurrence_key: recurrence_key,
        local_date: date,
        starts_at: time_result[:starts_at],
        ends_at: time_result[:starts_at] + series.duration_minutes.minutes,
        duration_minutes: series.duration_minutes,
        warnings: time_result[:warnings]
      )
    end

    if occurrences.size > MAX_OCCURRENCES
      return failure([
        "This recurrence would generate #{occurrences.size} sessions; " \
        "the maximum is #{MAX_OCCURRENCES}. Shorten the date range."
      ])
    end

    duplicates.each do |key, count|
      next if count < 2

      warnings << "Occurrence #{key} appears more than once"
    end

    Result.new(occurrences: occurrences, errors: [], warnings: warnings)
  end

  private

  attr_reader :series, :from, :through

  def failure(messages)
    Result.new(occurrences: [], errors: Array(messages), warnings: [])
  end

  def span_too_long?
    return false if series.starts_on.blank? || series.ends_on.blank?

    (series.ends_on - series.starts_on).to_i > MAX_SPAN_DAYS
  end

  def span_message
    "The recurrence window cannot exceed #{MAX_SPAN_DAYS} days"
  end

  def each_candidate_date
    # Callers may ask for a sub-window (generation top-ups, dashboard slices);
    # it is always clipped to the series' own start/end dates.
    window_start = [ from, series.starts_on ].compact.max
    window_end = [ through, series.ends_on ].compact.min
    return if window_start.blank? || window_end.blank? || window_start > window_end

    (window_start..window_end).each do |date|
      next unless weekday_numbers.include?(date.cwday)
      next unless on_interval_week?(date)

      yield date
    end
  end

  def weekday_numbers
    @weekday_numbers ||= series.weekdays.filter_map { |day| WEEKDAY_NUMBERS[day] }
  end

  # Weeks between the Monday of the series start week and the Monday of this
  # date's week. Anchoring on the start week (not on the first occurrence) keeps
  # interval behaviour stable when the start date itself is not a training day.
  def on_interval_week?(date)
    interval = series.interval.to_i
    return true if interval <= 1

    anchor = monday_of(series.starts_on)
    ((monday_of(date) - anchor).to_i / 7 % interval).zero?
  end

  def monday_of(date)
    date - (date.wday - 1) % 7
  end

  def resolve_local_start(date)
    hour = series.local_start_time.hour
    minute = series.local_start_time.min
    zone = series.time_zone_object
    local_time = Time.utc(date.year, date.month, date.day, hour, minute, 0)

    periods = zone.tzinfo.periods_for_local(local_time)
    if periods.empty?
      return { error: "#{date.iso8601} #{format_time(hour, minute)} does not exist " \
                     "in #{series.time_zone} (daylight-saving transition)" }
    end

    ambiguous = periods.size > 1
    # For a fall-back overlap the larger UTC offset is the earlier instant.
    period = ambiguous ? periods.max_by(&:utc_total_offset) : periods.first
    # TZInfo periods expose the offset, not a converter; subtracting it turns
    # the wall-clock components into the correct UTC instant.
    starts_at = (local_time - period.utc_total_offset).in_time_zone(zone)

    warnings = []
    if ambiguous
      warnings << "#{date.iso8601} #{format_time(hour, minute)} is ambiguous in " \
                  "#{series.time_zone}; the earlier occurrence was used"
    end

    { starts_at: starts_at, warnings: warnings }
  end

  def recurrence_key_for(date)
    "#{date.iso8601}T#{format_time(series.local_start_time.hour, series.local_start_time.min)}"
  end

  def format_time(hour, minute)
    format("%02d:%02d", hour, minute)
  end
end
