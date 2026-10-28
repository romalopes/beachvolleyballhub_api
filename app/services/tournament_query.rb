class TournamentQuery
  # Initialize with search/filter parameters
  # @param params [Hash] the query parameters
  # @option params [String] :search text search across name, organiser name/acronym, location
  # @option params [String] :scope tournament scope (club, state, national, international, other)
  # @option params [String] :organisation_id legacy filter by one organisation id
  # @option params [Array<String>] :organisation_ids filter by any selected organisation ids
  # @option params [String] :division_scheme division scheme (letter, numbered)
  # @option params [Array<String>] :letter_levels letter levels (e.g., ['B', 'BB'])
  # @option params [Array<Integer>] :division_numbers division numbers
  # @option params [String] :location text search across the tournament venue label and canonical location
  # @option params [String] :temporal_status one of 'upcoming', 'ongoing', 'completed'
  # @option params [Boolean] :mine when true, only tournaments where current account participates (legacy "participating")
  # @option params [Array<String>] :relationship tie kinds to filter by ('created', 'participating', 'following'), OR-combined
  # @option params [String] :publication_state publication state (draft, active, cancelled, archived)
  # @option params [String] :starts_at start of date range for overlap (UTC timestamp string)
  # @option params [String] :ends_at end of date range for overlap (UTC timestamp string)
  # @option params [Numeric] :latitude centre latitude for the radius filter
  # @option params [Numeric] :longitude centre longitude for the radius filter
  # @option params [Numeric] :radius_km radius in kilometres; needs latitude and longitude
  # @option params [Integer] :page page number for pagination
  # @option params [Integer] :per_page per page size for pagination
  def self.call(params = {})
    relation = Tournament.left_joins(:organisation, :location)

    # Text search
    if params[:search].present?
      search = params[:search].strip
      # Escape wildcard characters for ILIKE
      escaped_search = search.gsub(/[%_]/, '\\\\\\&')
      relation = relation.where(
        "tournaments.name ILIKE ? OR organisations.name ILIKE ? OR organisations.acronym ILIKE ? OR tournaments.location_name ILIKE ? OR locations.name ILIKE ? OR locations.formatted_address ILIKE ? OR locations.locality ILIKE ? OR locations.administrative_area ILIKE ? OR locations.country_code ILIKE ?",
        *Array.new(9, "%#{escaped_search}%")
      )
    end

    # Scope filter
    if params[:scope].present?
      relation = relation.where(scope: params[:scope])
    end

    # Organisation filter. `organisation_id` remains supported for existing
    # callers, while `organisation_ids` is the canonical multi-select filter.
    if params[:organisation_ids].present? && params[:organisation_ids].is_a?(Array)
      relation = relation.where(organisation_id: params[:organisation_ids])
    elsif params[:organisation_id].present?
      relation = relation.where(organisation_id: params[:organisation_id])
    end

    # Division scheme filter
    if params[:division_scheme].present?
      relation = relation.where(division_scheme: params[:division_scheme])
    end

    # Letter levels filter: tournaments with at least one active division at the
    # requested level (a subquery avoids duplicate tournament rows).
    if params[:letter_levels].present? && params[:letter_levels].is_a?(Array)
      letter_levels = params[:letter_levels].map(&:upcase)
      relation = relation.where(
        id: TournamentDivision.where(letter_level: letter_levels, active: true).select(:tournament_id)
      )
    end

    # Division numbers filter: tournaments with an active numbered division.
    if params[:division_numbers].present? && params[:division_numbers].is_a?(Array)
      division_numbers = params[:division_numbers].map(&:to_i)
      relation = relation.where(
        id: TournamentDivision.where(division_number: division_numbers, active: true).select(:tournament_id)
      )
    end

    # Location filter (free-text venue label plus canonical location fields)
    if params[:location].present?
      location = params[:location].strip
      escaped_location = location.gsub(/[%_]/, '\\\\\\&')
      relation = relation.where(
        "tournaments.location_name ILIKE ? OR locations.name ILIKE ? OR locations.formatted_address ILIKE ? OR locations.locality ILIKE ? OR locations.administrative_area ILIKE ? OR locations.country_code ILIKE ?",
        *Array.new(6, "%#{escaped_location}%")
      )
    end

    # Temporal status filter
    if params[:temporal_status].present?
      now = Time.current
      case params[:temporal_status]
      when 'upcoming'
        relation = relation.where("tournaments.starts_at > ?", now)
      when 'ongoing'
        relation = relation.where("tournaments.starts_at <= ? AND tournaments.ends_at > ?", now, now)
      when 'completed'
        relation = relation.where("tournaments.ends_at <= ?", now)
      end
    end

    # Radius filter: keep only tournaments whose canonical venue sits within
    # `radius_km` of (latitude, longitude). A bounding box on the plain
    # latitude/longitude columns narrows the candidate set, then the haversine
    # term rejects the box corners. Tournaments without canonical coordinates
    # (a free-text `location_name` only) cannot be measured and are excluded
    # while this filter is active.
    if (point = GeoRadius.point(params[:latitude], params[:longitude], params[:radius_km]))
      latitude, longitude, radius_km = point
      relation = relation.where(
        "locations.latitude BETWEEN ? AND ? AND locations.longitude BETWEEN ? AND ?",
        *GeoRadius.bounding_box(latitude, longitude, radius_km)
      ).where(GeoRadius::HAVERSINE_DISTANCE_SQL, latitude, latitude, longitude, radius_km)
    end

    # Mine filter: tournaments where the given account has a participation.
    # Legacy spelling of the "participating" relationship — kept so existing
    # callers and bookmarked URLs keep working.
    if params[:mine].present? && params[:mine] == true
      # Expect account_id to be passed in params when mine is true
      if params[:account_id].present?
        relation = relation.where(
          id: TournamentParticipation.where(account_id: params[:account_id]).select(:tournament_id)
        )
      else
        # If no account_id provided, return none
        relation = relation.none
      end
    end

    # Relationship filter: the kinds of tie between the caller and a tournament
    # — created, participating, or following. Several kinds may be requested at
    # once and are OR-combined (asking for "created" and "following" shows the
    # union, not the intersection). A subquery wraps the union so it ANDs
    # cleanly with the other filters above.
    if params[:relationship].present? && params[:relationship].is_a?(Array)
      kinds = params[:relationship].map(&:to_s) & %w[created participating following]
      account_id = params[:account_id]

      if kinds.empty? || account_id.blank?
        relation = relation.none
      else
        union = kinds.map do |kind|
          case kind
          when 'created'
            Tournament.where(created_by_account_id: account_id)
          when 'participating'
            Tournament.where(id: TournamentParticipation.where(account_id: account_id).select(:tournament_id))
          when 'following'
            Tournament.where(id: TournamentFollow.where(account_id: account_id).select(:tournament_id))
          end
        end.reduce { |combined, scope| combined.or(scope) }

        relation = relation.where(id: union.select(:id))
      end
    end

    # Publication state filter
    if params[:publication_state].present?
      # Only allow archived if admin? We'll leave authorization to the controller.
      relation = relation.where(publication_state: params[:publication_state])
    end

    # Date range overlap (for calendar queries)
    if params[:starts_at].present? && params[:ends_at].present?
      starts_at = parse_time(params[:starts_at])
      ends_at = parse_time(params[:ends_at])
      if starts_at && ends_at
        # Half-open overlap: [starts_at, ends_at)
        relation = relation.where(
          "tournaments.starts_at < ? AND tournaments.ends_at > ?",
          ends_at, starts_at
        )
      end
    end

    # Stable ordering
    relation = relation.order(starts_at: :asc, id: :asc)

    # Note: Pagination (limit/offset) should be applied by the controller.
    # We return the relation so the controller can paginate.

    relation
  end

  private_class_method def self.parse_time(time_input)
    return nil if time_input.blank?

    # If it's already a Time or DateTime, return as is (assuming UTC)
    if time_input.is_a?(Time) || time_input.is_a?(DateTime)
      time_input
    elsif time_input.is_a?(String)
      # Parse as UTC time
      Time.zone.parse(time_input).utc rescue nil
    else
      # Try to convert to time
      begin
        Time.zone.parse(time_input.to_s).utc
      rescue
        nil
      end
    end
  end
end