class TournamentUpdateService
  def self.call(tournament, params)
    ActiveRecord::Base.transaction do
      # Assign basic attributes if present
      tournament.name = params[:name] if params.key?(:name)
      tournament.organisation_id = params[:organisation_id] if params.key?(:organisation_id)
      tournament.created_by_account_id = params[:created_by_account_id] if params.key?(:created_by_account_id)
      tournament.scope = params[:scope] if params.key?(:scope)
      tournament.division_scheme = params[:division_scheme] if params.key?(:division_scheme)
      tournament.publication_state = params[:publication_state] if params.key?(:publication_state)
      tournament.website_url = params[:website_url] if params.key?(:website_url)
      tournament.description = params[:description] if params.key?(:description)
      tournament.location_name = params[:location_name] if params.key?(:location_name)
      tournament.city = params[:city] if params.key?(:city)
      tournament.state = params[:state] if params.key?(:state)
      tournament.country = params[:country] if params.key?(:country)
      tournament.timezone = params[:timezone] if params.key?(:timezone)

      # Handle all-day event and timezone conversion if starts_at or ends_at is present
      all_day = params.key?(:all_day) ? ActiveModel::Type::Boolean.new.cast(params[:all_day]) : tournament.all_day
      tournament.all_day = all_day

      # Parse and convert starts_at and ends_at if present
      if params.key?(:starts_at) || params.key?(:ends_at)
        begins_at = parse_time_in_timezone(params[:starts_at] || tournament.starts_at, tournament.timezone, all_day)
        ends_at = parse_time_in_timezone(params[:ends_at] || tournament.ends_at, tournament.timezone, all_day, begins_at)

        tournament.starts_at = begins_at
        tournament.ends_at = ends_at
      end

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
      if time_input.is_a?(String)
        # Try to parse as date first, then datetime
        begin
          date = Date.parse(time_input)
        rescue ArgumentError
          # If not a date, try datetime and then extract date
          datetime = time_zone.parse(time_input)
          date = datetime.to_date
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