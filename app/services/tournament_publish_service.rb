class TournamentPublishService
  extend InvalidRecord

  def self.call(tournament)
    ActiveRecord::Base.transaction do
      unless tournament.has_active_division?
        raise_invalid!(tournament, "Cannot publish tournament without at least one active division")
      end

      tournament.publication_state = :active
      tournament.save!
      tournament
    end
  end
end