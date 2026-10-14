class Tournament < ApplicationRecord
  belongs_to :organisation
  belongs_to :created_by_account, class_name: 'Account'
  has_many :divisions, class_name: 'TournamentDivision', dependent: :destroy
  has_many :participations, class_name: 'TournamentParticipation', dependent: :destroy
  has_many :watch_links, class_name: 'TournamentWatchLink', dependent: :destroy

  enum :scope, { club: 0, state: 1, national: 2, international: 3, other: 4 }
  enum :publication_state, { draft: 0, active: 1, cancelled: 2, archived: 3 }

  validates :name, presence: true
  validates :scope, presence: true, inclusion: { in: scopes.keys }
  validates :division_scheme, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :timezone, presence: true
  validates :publication_state, presence: true, inclusion: { in: publication_states.keys }
  validates :website_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }
  validate :ends_after_starts

  def ends_after_starts
    if starts_at.present? && ends_at.present? && ends_at <= starts_at
      errors.add(:ends_at, "must be after the start date")
    end
  end

  def active_divisions
    divisions.where(active: true)
  end

  def has_active_division?
    active_divisions.exists?
  end
end