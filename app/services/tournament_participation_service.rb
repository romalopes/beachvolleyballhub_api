class TournamentParticipationService
  def self.link_or_update_participation(account_id, tournament_id, role: nil, division_ids: [])
    ActiveRecord::Base.transaction do
      tournament = Tournament.find(tournament_id)

      # Check if tournament is active and not completed (archived or cancelled) for link/update
      unless tournament.active? && !tournament.archived? && !tournament.cancelled?
        raise ActiveRecord::RecordInvalid.new(tournament, "Can only link or update participation for active, non-completed tournaments")
      end

      # Find or create participation
      participation = TournamentParticipation.find_or_initialize_by(
        account_id: account_id,
        tournament_id: tournament_id
      )

      # Update role if provided
      participation.role = role if role.present?

      participation.save!

      # Update divisions: we replace the existing divisions with the given list
      # First, remove any existing participation divisions not in the new list
      participation.tournament_participation_divisions.where.not(tournament_division_id: division_ids).destroy_all

      # Add new division links
      division_ids.each do |division_id|
        # Ensure the division belongs to the tournament
        unless tournament.divisions.exists?(id: division_id)
          raise ActiveRecord::RecordInvalid.new(tournament, "Division #{division_id} does not belong to tournament #{tournament_id}")
        end

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