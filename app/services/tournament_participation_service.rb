class TournamentParticipationService
  extend InvalidRecord

  def self.link_or_update_participation(account_id, tournament_id, role: nil, division_ids: [])
    ActiveRecord::Base.transaction do
      tournament = Tournament.find(tournament_id)
      # Serialize against division/lifecycle mutations on the same tournament.
      tournament.lock!

      # Only active, non-completed tournaments accept new links or role/division
      # changes; unlinking stays possible at any point (see unlink_participation).
      unless tournament.active? && tournament.ends_at > Time.current
        raise_invalid!(tournament, "Can only link or update participation for active, non-completed tournaments")
      end

      # Find or create participation
      participation = TournamentParticipation.find_or_initialize_by(
        account_id: account_id,
        tournament_id: tournament_id
      )

      # Update role if provided
      participation.role = role if role.present?

      participation.save!

      division_ids = Array(division_ids).map(&:to_i).uniq
      if !%w[player coach].include?(participation.role) && division_ids.any?
        raise_invalid!(tournament, "Only player and coach participation can include divisions")
      end

      divisions = tournament.divisions.where(id: division_ids).index_by(&:id)
      missing_ids = division_ids - divisions.keys
      unless missing_ids.empty?
        raise_invalid!(tournament, "Division #{missing_ids.first} does not belong to tournament #{tournament_id}")
      end

      existing_division_ids = participation.participation_divisions.pluck(:tournament_division_id)
      inactive_new_division = divisions.values.find { |division| !division.active? && !existing_division_ids.include?(division.id) }
      if inactive_new_division
        raise_invalid!(tournament, "Division #{inactive_new_division.id} is inactive")
      end

      # Update divisions: we replace the existing divisions with the given list.
      # Existing inactive selections can be retained but cannot be newly added.
      # First, remove any existing participation divisions not in the new list
      participation.participation_divisions.where.not(tournament_division_id: division_ids).destroy_all

      # Add new division links
      division_ids.each do |division_id|
        # Find or create the participation division
        TournamentParticipationDivision.find_or_create_by(
          tournament_participation_id: participation.id,
          tournament_division_id: division_id,
          tournament_id: tournament_id
        )
      end

      participation
    end
  end

  def self.unlink_participation(account_id, tournament_id)
    ActiveRecord::Base.transaction do
      participation = TournamentParticipation.find_by(
        account_id: account_id,
        tournament_id: tournament_id
      )

      # Allow unlinking even if tournament is archived or cancelled (as per requirement)
      if participation
        participation.destroy
      end

      # Return nil or the destroyed participation? We'll return nil for simplicity.
      nil
    end
  end
end