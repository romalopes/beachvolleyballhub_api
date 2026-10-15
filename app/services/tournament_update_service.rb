class TournamentUpdateService
  extend InvalidRecord

  def self.call(tournament, params)
    ActiveRecord::Base.transaction do
      # Lock the parent so a concurrent participation link and a scheme change
      # cannot interleave (Phase 2 concurrency gate).
      tournament.lock!

      # Scheme immutability: once any participation exists the scheme is locked —
      # division codes and participation selections are expressed in its terms.
      if params.key?(:division_scheme) &&
         params[:division_scheme].to_s != tournament.division_scheme &&
         tournament.participations.exists?
        raise_invalid!(
          tournament,
          "Division scheme cannot be changed after participation begins"
        )
      end

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
      # An invalid timezone must fail loudly at assignment time, even when no
      # date parsing follows (a timezone-only update still changes how stored
      # instants would be interpreted).
      if params.key?(:timezone) && !ActiveSupport::TimeZone[params[:timezone]]
        raise ArgumentError, "Invalid timezone: #{params[:timezone]}"
      end

      # Handle all-day event and timezone conversion if starts_at or ends_at is present
      all_day = params.key?(:all_day) ? ActiveModel::Type::Boolean.new.cast(params[:all_day]) : tournament.all_day
      tournament.all_day = all_day

      # Parse and convert starts_at and ends_at if present. Values not supplied
      # come from the stored row and are re-anchored through the event timezone,
      # so partial updates cannot drift the local date.
      if params.key?(:starts_at) || params.key?(:ends_at)
        tournament.starts_at = TournamentTime.parse_in_timezone(
          params[:starts_at] || tournament.starts_at, tournament.timezone, all_day: all_day
        )
        tournament.ends_at = TournamentTime.parse_in_timezone(
          params[:ends_at] || tournament.ends_at, tournament.timezone,
          all_day: all_day, end_of_day: true
        )
      end

      # Validate the tournament (will run ends_after_starts validation)
      tournament.save!

      tournament
    end
  end
end
