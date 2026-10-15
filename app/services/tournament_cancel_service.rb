# Cancelling a tournament is a first-class lifecycle action (Phase 2), separate
# from archiving: a cancelled tournament stays visible as cancelled history,
# while archive hides it. Cancelling is idempotent; archived rows must be
# restored first so a tournament can never skip through archived via cancelled.
class TournamentCancelService
  extend InvalidRecord

  def self.call(tournament)
    ActiveRecord::Base.transaction do
      tournament.lock!

      if tournament.archived?
        raise_invalid!(
          tournament,
          "Archived tournaments must be restored before they can be cancelled"
        )
      end

      unless tournament.cancelled?
        tournament.publication_state = :cancelled
        tournament.save!
      end

      tournament
    end
  end
end
