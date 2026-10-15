# Shared timezone-aware parsing for tournament boundaries.
#
# Produces UTC instants from wall-clock input interpreted in the tournament's
# IANA timezone:
# - timed events: the given local time converted to UTC;
# - all-day events: the given local DATE anchored to 00:00:00 local (start) or
#   23:59:59 local (end, via +end_of_day+) so a single-day tournament always
#   satisfies ends_at > starts_at — the contract pinned by
#   tournament_create_service_test.
#
# Non-string inputs (already-stored Time values re-processed during partial
# updates) are converted through the event timezone first, so repeated updates
# cannot drift the local date across a UTC offset boundary.
module TournamentTime
  module_function

  def parse_in_timezone(time_input, timezone_str, all_day:, end_of_day: false)
    return nil if time_input.blank?

    unless ActiveSupport::TimeZone[timezone_str]
      raise ArgumentError, "Invalid timezone: #{timezone_str}"
    end

    time_zone = ActiveSupport::TimeZone[timezone_str]

    if all_day
      date = local_date(time_input, time_zone)
      boundary = time_zone.local(date.year, date.month, date.day, 0, 0, 0)
      boundary += 23.hours + 59.minutes + 59.seconds if end_of_day
      boundary.utc
    else
      time =
        case time_input
        when String then time_zone.parse(time_input)
        when Time then time_input
        when DateTime then time_input.to_time
        else time_zone.parse(time_input.to_s)
        end
      raise ArgumentError, "Could not parse time: #{time_input.inspect}" if time.nil?

      time.utc
    end
  end

  # The calendar date an all-day boundary belongs to, read in the event's
  # timezone rather than UTC.
  def local_date(time_input, time_zone)
    case time_input
    when String
      begin
        Date.parse(time_input)
      rescue ArgumentError
        datetime = time_zone.parse(time_input)
        raise ArgumentError, "Could not parse date: #{time_input.inspect}" if datetime.nil?

        datetime.to_date
      end
    when Time
      time_input.in_time_zone(time_zone).to_date
    else
      Date.parse(time_input.to_s)
    end
  end
end
