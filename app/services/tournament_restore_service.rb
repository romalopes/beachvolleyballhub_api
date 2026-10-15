# Restore is the inverse of archive/cancel (Phase 2). It always lands in
# draft: re-publishing requires at least one active division and is a
# deliberate act, so a tournament that was cancelled or archived never
# reappears as active without an admin publishing it again.
class TournamentRestoreService
  extend InvalidRecord

  def self.call(tournament)
    ActiveRecord::Base.transaction do
      tournament.lock!

      unless tournament.archived? || tournament.cancelled?
        raise_invalid!(
          tournament,
          "Only archived or cancelled tournaments can be restored"
        )
      end

      tournament.publication_state = :draft
      tournament.save!

      tournament
    end
  end
end
