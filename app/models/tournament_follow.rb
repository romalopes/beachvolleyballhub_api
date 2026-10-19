# A lightweight bookmark: an Account that wants a Tournament in its watching
# list without (yet) participating in it.
#
# Deliberately thinner than TournamentParticipation — no role, no divisions, no
# lifecycle columns beyond the row itself: unfollowing deletes the row, so a
# follow has no history to preserve. Uniqueness is guarded by the model
# validation and mirrored by a composite unique index that wins any race.
class TournamentFollow < ApplicationRecord
  belongs_to :account
  belongs_to :tournament

  validates :account_id, presence: true
  validates :tournament_id, presence: true
  validates :account_id, uniqueness: { scope: :tournament_id }
end