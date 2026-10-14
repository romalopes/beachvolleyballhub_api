class TournamentParticipationDivision < ApplicationRecord
  belongs_to :tournament_participation
  belongs_to :tournament_division
  belongs_to :tournament

  validates :tournament_participation_id, presence: true
  validates :tournament_division_id, presence: true
  validates :tournament_id, presence: true
  validates :tournament_participation_id, uniqueness: { scope: :tournament_division_id }

  # Ensure the tournament matches via participation and division (database constraint also exists)
  validate :tournament_consistency

  def tournament_consistency
    if tournament_participation_id.present? && tournament_division_id.present? && tournament_id.present?
      participation_tournament_id = TournamentParticipation.find_by(id: tournament_participation_id)&.tournament_id
      division_tournament_id = TournamentDivision.find_by(id: tournament_division_id)&.tournament_id
      unless participation_tournament_id == tournament_id && division_tournament_id == tournament_id
        errors.add(:base, "Tournament mismatch between participation, division, and record")
      end
    end
  end
end