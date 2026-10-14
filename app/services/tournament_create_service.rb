class TournamentCreateService
  def self.call(params)
    ActiveRecord::Base.transaction do
      tournament = Tournament.new

      # Assign basic attributes
      tournament.name = params[:name]
      tournament.organisation_id = params[:organisation_id]
      tournament.created_by_account_id = params[:created_by_account_id]
      tournament.scope = params[:scope]
      tournament.division_scheme = params[:division_scheme]
      tournament.publication_state = params[:publication_state] || :draft
      tournament.website_url = params[:website_url]
      tournament.description = params[:description]
      tournament.location_name = params[:location_name]
      tournament.city = params[:city]
      tournament.state = params[:state]
      tournament.country = params[:country]
      tournament.timezone = params[:timezone]

      # Handle all-day event and timezone conversion
      all_day = ActiveModel::Type::Boolean.new.cast(params[:all_day])
      tournament.all_day = all_day

      # Parse and convert starts_at and ends_at
      begins_at = parse_time_in_timezone(params[:starts_at], tournament.timezone, all_day)
      ends_at = parse_time_in_timezone(params[:ends_at], tournament.timezone, all_day, begins_at)

      tournament.starts_at = begins_at
      tournament.ends_at = ends_at

      # Validate the tournament (will run ends_after_starts validation)
      tournament.save!

      tournament
    end
  end

  private_class_method def self.parse_time_in_timezone(time_input, timezone_str, all_day, begins_at = nil)
    return nil if time_input.blank?

    # Validate timezone
    unless ActiveSupport::TimeZone[timezone_str]
      raise ArgumentError, "Invalid timezone: #{timezone_str}"
    end

    time_zone = ActiveSupport::TimeZone[timezone_str]

    if all_day
      # For all-day events, we expect the input to be a date (or datetime) representing the start date.
      # If we are given a datetime, we extract the date part.
      # If begins_at is provided (for ends_at calculation), we use the same date as begins_at? 
      # Actually, for all-day events, we have two inputs: starts_at and ends_at as dates.
      # We'll convert the starts_at input to a date in the timezone, then set the time to 00:00:00
      # and the ends_at input to a date in the timezone, then set the time to 23:59:59.999999.
      # But note: the input might be a string like "2026-10-15" or a datetime.

      # Parse the input to a date in the timezone
      if time_input.is_a?(String)
        # Try to parse as date first, then datetime
        begin
          date = Date.parse(time_input)
        rescue ArgumentError
          # If not a date, try datetime and then extract date
          datetime = time_zone.parse(time_input)
          date = date.to_date
        end
      elsif time_input.is_a?(DateTime) || time_input.is_a?(Time)
        date = time_input.to_date
      else
        # Assume it's a date-like object
        date = Date.parse(time_input.to_s)
      end

      # Create a time at the beginning of the day in the timezone
      beginning_of_day = time_zone.local(date.year, date.month, date.day, 0, 0, 0)
      # Convert to UTC
      beginning_of_day.utc

    else
      # For timed events, parse the input as a time in the timezone and convert to UTC
      if time_input.is_a?(String)
        time = time_zone.parse(time_input)
      elsif time_input.is_a?(DateTime) || time_input.is_a?(Time)
        time = time_input
      else
        time = time_zone.parse(time_input.to_s)
      end

      # Convert to UTC
      time.utc
    end
  end
end