class TournamentArchiveService
  def self.call(tournament)
    ActiveRecord::Base.transaction do
      tournament.publication_state = :archived
      tournament.save!
      tournament
    end
  end
end