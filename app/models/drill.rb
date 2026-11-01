# Explicitly require the validator: app/validators was added after the running
# server booted, and Zeitwerk only picks up new autoload roots at boot. The
# eager require keeps this robust across stale dev-server processes.
require Rails.root.join("app/validators/drill_definition_validator")

class Drill < ApplicationRecord
  include Sluggable
  source_column :title

  belongs_to :created_by, class_name: "User", optional: true
  # The content manager who published or rejected the drill (approval state).
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :drill_skills, dependent: :destroy
  has_many :skills, through: :drill_skills
  has_many :video_references, as: :referenced, dependent: :destroy
  has_many :videos, through: :video_references
  # A drill is referenced by training sessions through ordered join rows; the
  # join row is destroyed with the drill, never the training session itself.
  has_many :training_session_drills, dependent: :destroy
  has_many :training_sessions, through: :training_session_drills

  validates :title, presence: true

  validate :definition_must_be_valid

  TRAINING_STAGES = %w[warmup beginning middle end].freeze
  DIFFICULTY_LEVELS = %w[beginner intermediate advanced].freeze
  VISIBILITY_LEVELS = %w[shared private unlisted].freeze
  STATUS_LEVELS = %w[draft submitted published archived rejected].freeze

  enum :visibility, { shared: "shared", private: "private", unlisted: "unlisted" }, prefix: true
  enum :status, { draft: "draft", submitted: "submitted", published: "published", archived: "archived", rejected: "rejected" }, prefix: true

  # These training attributes are optional: inclusion/numericality skip nil
  # values (allow_nil), while cross-field checks still apply whenever both
  # sides of the comparison are present.
  validates :training_stage, inclusion: { in: TRAINING_STAGES, allow_nil: true }
  validates :difficulty_level, inclusion: { in: DIFFICULTY_LEVELS, allow_nil: true }
  # `visibility` and `status` are enforced by the enums above: Rails raises
  # ArgumentError on an unknown value, so no separate inclusion validation is
  # needed (and one would be unreachable).
  validates :min_players, :max_players, :ideal_num_players,
            numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :min_players_not_greater_than_max_players
  validate :ideal_num_players_within_range
  validate :rejected_requires_approval_not_future

  # Stamp `published_at` the first time a drill becomes published, whichever
  # path set the status (admin form, coach submit, or the `publish!` helper).
  before_save :stamp_published_at

  # Scope: drills safe for public consumption — published and shared visibility.
  scope :published_and_shared, -> { where(status: :published, visibility: :shared) }
  # Scope: drills visible to the creator regardless of status/visibility.
  scope :visible_to, ->(user) { where(created_by: user).or(published_and_shared) }

  # True when this drill is published and shared — safe for public endpoints.
  def published_and_shared?
    status == "published" && visibility == "shared"
  end

  def publish!(approver: nil)
    transaction do
      update!(status: :published, published_at: Time.current, approved_by: approver)
    end
  end

  def reject!(approver: nil)
    transaction do
      update!(status: :rejected, approved_at: Time.current, approved_by: approver)
    end
  end

  def training_stage_label
    return nil if training_stage.nil?
    training_stage == "warmup" ? "Warm-up" : training_stage.to_s.capitalize
  end

  def player_range_label
    return nil if min_players.nil? || max_players.nil?
    min_players == max_players ? "#{min_players} players" : "#{min_players}–#{max_players} players"
  end

  def ideal_label
    ideal_num_players.nil? ? nil : "Ideal: #{ideal_num_players}"
  end

  # True when the drill carries a renderable v1 visual definition. The JSONB
  # column defaults to `{}` (no visualisation yet); the validator enforces a
  # schema-valid definition (with at least one step) whenever it is non-empty,
  # so a present `steps` array is the exact signal list endpoints can expose
  # without shipping the whole definition.
  def has_definition
    definition.is_a?(Hash) && definition["steps"].present?
  end

  def to_param
    slug
  end

  private

  def stamp_published_at
    self.published_at ||= Time.current if status == "published"
  end

  def rejected_requires_approval_not_future
    if status == "rejected" && approved_at && approved_at > Time.current
      errors.add(:approved_at, "cannot be in the future")
    end
  end

  def definition_must_be_valid
    DrillDefinitionValidator.new(self).validate
  end

  def min_players_not_greater_than_max_players
    return if min_players.nil? || max_players.nil?
    errors.add(:min_players, "must be less than or equal to max players") if min_players > max_players
  end

  def ideal_num_players_within_range
    return if ideal_num_players.nil? || min_players.nil? || max_players.nil?
    unless ideal_num_players >= min_players && ideal_num_players <= max_players
      errors.add(:ideal_num_players, "must be between min and max players (inclusive)")
    end
  end
end
