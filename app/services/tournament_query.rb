class TournamentQuery
  # Initialize with search/filter parameters
  # @param params [Hash] the query parameters
  # @option params [String] :search text search across name, organiser name/acronym, location
  # @option params [String] :scope tournament scope (club, state, national, international, other)
  # @option params [String] :organisation_id filter by organisation id
  # @option params [String] :division_scheme division scheme (letter, numbered)
  # @option params [Array<String>] :letter_levels letter levels (e.g., ['B', 'BB'])
  # @option params [Array<Integer>] :division_numbers division numbers
  # @option params [String] :location text search across location_name, city, state, country
  # @option params [String] :temporal_status one of 'upcoming', 'ongoing', 'completed'
  # @option params [Boolean] :mine when true, only tournaments where current account participates
  # @option params [String] :publication_state publication state (draft, active, cancelled, archived)
  # @option params [String] :starts_at start of date range for overlap (UTC timestamp string)
  # @option params [String] :ends_at end of date range for overlap (UTC timestamp string)
  # @option params [Integer] :page page number for pagination
  # @option params [Integer] :per_page per page size for pagination
  def self.call(params = {})
    relation = Tournament.all

    # Text search
    if params[:search].present?
      search = params[:search].strip
      # Escape wildcard characters for ILIKE
      escaped_search = search.gsub(/[%_]/, '\\\\\\&')
      relation = relation.where(
        "tournaments.name ILIKE ? OR organisations.name ILIKE ? OR organisations.acronym ILIKE ? OR tournaments.location_name ILIKE ? OR tournaments.city ILIKE ? OR tournaments.state ILIKE ? OR tournaments.country ILIKE ?",
        "%#{escaped_search}%", "%#{escaped_search}%", "%#{escaped_search}%",
        "%#{escaped_search}%", "%#{escaped_search}%", "%#{escaped_search}%", "%#{escaped_search}%"
      ).joins(:organisation)
    end

    # Scope filter
    if params[:scope].present?
      relation = relation.where(scope: params[:scope])
    end

    # Organisation filter
    if params[:organisation_id].present?
      relation = relation.where(organisation_id: params[:organisation_id])
    end

    # Division scheme filter
    if params[:division_scheme].present?
      relation = relation.where(division_scheme: params[:division_scheme])
    end

    # Letter levels filter (using EXISTS to avoid duplicate tournaments)
    if params[:letter_levels].present? && params[:letter_levels].is_a?(Array)
      letter_levels = params[:letter_levels].map(&:upcase)
      relation = relation.where(
        EXISTS(
          TournamentDivision.select(1)
            .where("tournament_divisions.tournament_id = tournaments.id")
            .where(letter_level: letter_levels)
            .where(active: true)
        )
      )
    end

    # Division numbers filter (using EXISTS)
    if params[:division_numbers].present? && params[:division_numbers].is_a?(Array)
      division_numbers = params[:division_numbers].map(&:to_i)
      relation = relation.where(
        EXISTS(
          TournamentDivision.select(1)
            .where("tournament_divisions.tournament_id = tournaments.id")
            .where(division_number: division_numbers)
            .where(active: true)
        )
      )
    end

    # Location filter (text search across location fields)
    if params[:location].present?
      location = params[:location].strip
      escaped_location = location.gsub(/[%_]/, '\\\\\\&')
      relation = relation.where(
        "tournaments.location_name ILIKE ? OR tournaments.city ILIKE ? OR tournaments.state ILIKE ? OR tournaments.country ILIKE ?",
        "%#{escaped_location}%", "%#{escaped_location}%", "%#{escaped_location}%", "%#{escaped_location}%"
      )
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

    # Mine filter: tournaments where the current account has a participation
    if params[:mine].present? && params[:mine] == true
      # Expect account_id to be passed in params when mine is true
      if params[:account_id].present?
        relation = relation.where(
          EXISTS(
            TournamentParticipation.select(1)
              .where("tournament_participations.tournament_id = tournaments.id")
              .where(account_id: params[:account_id])
          )
        )
      else
        # If no account_id provided, return none
        relation = relation.none
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
    if time_input.is_a?(Time) || time_input.is_a!(DateTime)
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
    end