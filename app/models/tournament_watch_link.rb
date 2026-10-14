class TournamentWatchLink < ApplicationRecord
  belongs_to :tournament

  validates :tournament_id, presence: true
  validates :name, presence: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :provider, presence: true
  validates :starts_at, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end