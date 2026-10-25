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
      default_location = LocationDefaultResolver.for_event(organisation_id: params[:organisation_id])
      tournament.location_id = params.key?(:location_id) ? params[:location_id] : default_location&.id
      tournament.court_id = params[:court_id]
      tournament.location_detail = params[:location_detail]
      if default_location && tournament.location_id == default_location.id && tournament.location_name.blank?
        tournament.location_name = default_location.name
      end
      tournament.timezone = params[:timezone]

      # Handle all-day event and timezone conversion
      all_day = ActiveModel::Type::Boolean.new.cast(params[:all_day])
      tournament.all_day = all_day

      # Parse and convert starts_at and ends_at. The end of an all-day event is
      # anchored to 23:59:59 in the event timezone so a single-day tournament
      # always satisfies ends_at > starts_at (contract pinned by the service
      # tests); timed events keep their exact local wall time.
      tournament.starts_at = TournamentTime.parse_in_timezone(
        params[:starts_at], tournament.timezone, all_day: all_day
      )
      tournament.ends_at = TournamentTime.parse_in_timezone(
        params[:ends_at], tournament.timezone, all_day: all_day, end_of_day: true
      )

      # Validate the tournament (will run ends_after_starts validation)
      tournament.save!

      tournament
    end
  end
end
