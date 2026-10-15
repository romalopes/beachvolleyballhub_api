class TournamentParticipation < ApplicationRecord
  belongs_to :account
  belongs_to :tournament
  has_many :participation_divisions, class_name: 'TournamentParticipationDivision', dependent: :destroy

  # String-backed on purpose: `role` is a string column, so the enum values are
  # the labels — integer values would persist as "0"/"1"/… and never match the
  # API contract (`player`, `coach`, …).
  enum :role, { player: "player", coach: "coach", referee: "referee", organiser: "organiser" }

  validates :account_id, presence: true
  validates :tournament_id, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :account_id, uniqueness: { scope: :tournament_id }

  # Scope for organisers
  def self.organisers
    where(role: :organiser)
  end
end