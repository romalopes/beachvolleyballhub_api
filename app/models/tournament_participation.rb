class TournamentParticipation < ApplicationRecord
  belongs_to :account
  belongs_to :tournament
  has_many :participation_divisions, class_name: 'TournamentParticipationDivision', dependent: :destroy

  enum :role, { player: 0, coach: 1, referee: 2, organiser: 3 }

  validates :account_id, presence: true
  validates :tournament_id, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :account_id, uniqueness: { scope: :tournament_id }

  # Scope for organisers
  def self.organisers
    where(role: :organiser)
  end
end