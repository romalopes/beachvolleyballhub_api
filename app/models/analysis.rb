class Analysis < ApplicationRecord
  STATUSES = %w[draft published archived].freeze

  belongs_to :created_by, class_name: "User"
  belongs_to :assigned_coach_profile, class_name: "CoachProfile", optional: true
  belongs_to :organisation, optional: true
  belongs_to :group, optional: true
  belongs_to :training_session, optional: true
  belongs_to :tournament, optional: true

  has_many :analysis_participants, dependent: :destroy, inverse_of: :analysis
  has_many :player_profiles, through: :analysis_participants
  has_many :analysis_videos, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :analysis
  has_many :analysis_comments, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :analysis
  has_many :analysis_assessment_sessions, dependent: :destroy, inverse_of: :analysis
  has_many :assessment_sessions, through: :analysis_assessment_sessions

  validates :title, presence: true, length: { maximum: 160 }
  validates :status, inclusion: { in: STATUSES }
  validate :assigned_coach_is_connected

  scope :ordered, -> { order(updated_at: :desc, id: :desc) }
  scope :published, -> { where(status: "published") }

  def draft? = status == "draft"
  def published? = status == "published"
  def archived? = status == "archived"

  def publish! = update!(status: "published", published_at: Time.current, archived_at: nil)
  def archive! = update!(status: "archived", archived_at: Time.current)

  private

  def assigned_coach_is_connected
    return if assigned_coach_profile.nil? || assigned_coach_profile.account_id.present?
    errors.add(:assigned_coach_profile, "must be connected to an account")
  end
end