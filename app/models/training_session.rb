# A scheduled beach volleyball training.
#
# Training Sessions are shared schedule resources: `created_by` records who
# created the session (audit only) and never acts as a private ownership
# boundary. Management is role-based (ContentAuthorization). Visibility is a
# mix of the shared schedule and personal participation: every non-manager
# sees the non-draft schedule plus the sessions they participate in (see
# `visible_to`). Drafts remain private to managers regardless of
# participation.
#
# Participants reference the PlayerProfile (domain identity), never the User,
# so accountless players can participate and keep attendance history.
#
# Focuses describe what the training works on (an existing Skill or custom
# text); drills are selected explicitly by the coach. A drill is only
# referenced through TrainingSessionDrill — its description, visual definition
# and steps always come from the Drill itself, so future Drill versioning can
# slot in without touching this model.
class TrainingSession < ApplicationRecord
  STATUSES = %w[draft scheduled cancelled completed].freeze

  # Drafts are internal working copies. Everything else belongs to the shared
  # schedule and is visible to anyone who can browse the application.
  PUBLICLY_VISIBLE_STATUSES = (STATUSES - [ "draft" ]).freeze

  # Visibility dimension (orthogonal to status):
  #   * shared  — on the shared schedule, visible to everyone browsing;
  #   * private — visible only to its participants and to training managers,
  #     so a coach can schedule a training for a specific player or group
  #     without publishing it to everyone.
  VISIBILITIES = %w[shared private].freeze

  belongs_to :created_by, class_name: "User", optional: true

  # Recurring training links. All are optional: one-off sessions (including
  # every session created before this feature) have no series or template.
  belongs_to :training_series, optional: true, inverse_of: :training_sessions
  belongs_to :training_template, optional: true
  # Schedule metadata copied from the series defaults. These are not an
  # authorization boundary — training management stays role-based.
  belongs_to :organisation, optional: true
  belongs_to :group, optional: true
  belongs_to :coach_profile, optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true

  has_many :training_focuses, -> { order(:position, :id) },
           dependent: :destroy, inverse_of: :training_session
  has_many :training_session_drills, -> { order(:position, :id) },
           dependent: :destroy, inverse_of: :training_session
  has_many :drills, through: :training_session_drills
  has_many :training_session_participants,
           dependent: :destroy, inverse_of: :training_session
  has_many :player_profiles, through: :training_session_participants

  # Assessments recorded during this session outlive it: a coach's rating of a
  # player is not undone by the schedule entry being deleted, which is why the
  # column's foreign key is ON DELETE SET NULL.
  has_many :assessments, dependent: :nullify, inverse_of: :training_session

  # Media: the polymorphic VideoReference lets a training session carry videos
  # (e.g. a recording of the session) without a dedicated join table.
  has_many :video_references, as: :referenced, dependent: :destroy
  has_many :videos, through: :video_references

  accepts_nested_attributes_for :training_focuses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :training_session_drills, allow_destroy: true, reject_if: :all_blank
  # A participant row is meaningful only when it references (or creates) a
  # player profile; the controller turns inline `person:` rows into profiles.
  accepts_nested_attributes_for :training_session_participants, allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:player_profile_id].blank? }

  validates :title, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :visibility, presence: true, inclusion: { in: VISIBILITIES }
  validates :recurrence_key, presence: true, if: :series_occurrence?
  # The partial unique index in the database is the real guard against a
  # double-generation race; this validation is what turns the collision into a
  # readable error instead of a 500.
  validates :recurrence_key, uniqueness: { scope: :training_series_id }, allow_nil: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_at_after_starts_at
  validate :series_template_is_consistent

  scope :ordered, -> { order(:starts_at, :id) }
  # Calendar support: only load the window being displayed.
  scope :starting_between, ->(from, to) {
    scope = all
    scope = scope.where(starts_at: from..) if from.present?
    scope = scope.where(starts_at: ..to) if to.present?
    scope
  }
  # Sessions a given PlayerProfile participates in ("my schedule").
  # Note: this scope is participation only — it includes drafts and private
  # sessions. Gate user-facing access through `visible_to`, which excludes
  # drafts for non-managers.
  scope :participated_by, ->(player_profile) {
    joins(:training_session_participants)
      .where(training_session_participants: { player_profile_id: player_profile.id })
  }

  # Visibility:
  #   * managers (coach/curator/admin) see everything, including drafts and
  #     private sessions;
  #   * a signed-in player sees shared non-draft sessions plus the non-draft
  #     private sessions they participate in ("their own schedule");
  #   * everyone else (players without a profile, guests) sees only the shared
  #     non-draft schedule.
  # Drafts are never exposed through this scope to non-managers, even when
  # they participate.
  scope :visible_to, ->(user) {
    non_drafts = where(status: PUBLICLY_VISIBLE_STATUSES)
    shared = non_drafts.where(visibility: "shared")
    if user.respond_to?(:content_manager?) && user.content_manager?
      all
    elsif user.respond_to?(:account) && (profile = user.account&.player_profiles&.first)
      participant_ids = TrainingSessionParticipant.where(player_profile_id: profile.id).pluck(:training_session_id)
      shared.or(non_drafts.where(id: participant_ids))
    else
      shared
    end
  }

  def self.participating_scope_for(player_profile)
    joins(:training_session_participants)
      .where(training_session_participants: { player_profile_id: player_profile.id })
  end

  # Occurrences generated from a series, and the upcoming slice used by the
  # dashboard/eligibility helpers.
  scope :for_series, ->(series) {
    where(training_series_id: series.is_a?(TrainingSeries) ? series.id : series)
  }
  scope :starting_from, ->(time) { where(starts_at: time..) }
  scope :scheduled, -> { where(status: "scheduled") }

  def series_occurrence?
    training_series_id.present?
  end

  # True once an occurrence has diverged from its series defaults. The keys are
  # field names (e.g. "title", "coach_profile_id").
  def overridden?
    override_fields.present?
  end

  def overridden_field?(field)
    override_fields.key?(field.to_s)
  end

  def cancellable?
    draft? || scheduled?
  end

  # Deletion is deliberately narrower than cancellation: only a draft that has
  # never accumulated participants or assessments can disappear.
  def deletable_occurrence?
    draft? && training_session_participants.none? && assessments.none?
  end

  # Cancellation keeps the row (and its recurrence_key) as a tombstone so a
  # later generation run cannot resurrect it.
  def mark_cancelled!(reason:, actor: nil)
    update!(
      status: "cancelled",
      cancellation_reason: reason,
      cancelled_at: Time.current,
      cancelled_by: actor
    )
  end

  def draft?
    status == "draft"
  end

  def scheduled?
    status == "scheduled"
  end

  def cancelled?
    status == "cancelled"
  end

  def completed?
    status == "completed"
  end

  def status_label
    status.to_s.capitalize
  end

  # Non-draft trainings belong to the shared schedule.
  def publicly_visible?
    !draft? && shared?
  end

  def shared?
    visibility == "shared"
  end

  def private?
    visibility == "private"
  end

  # Single source of truth for "may this user see this session's details?"
  # (drafts and private sessions stay hidden from anyone except managers and
  # — for non-draft private sessions — their participants). Controllers and
  # views must use this instead of reimplementing the rules.
  def visible_to_user?(user)
    return true if user.respond_to?(:content_manager?) && user.content_manager?
    return false if draft?
    return true if shared?

    profile = user.respond_to?(:account) ? user.account&.player_profiles&.first : nil
    return false if profile.nil?

    training_session_participants.any? { |p| p.player_profile_id == profile.id }
  end

  # Total scheduled length in minutes (the sum of the selected drills may
  # differ; this reflects the calendar block).
  def duration_minutes
    return nil if starts_at.nil? || ends_at.nil?

    ((ends_at - starts_at) / 60).round
  end

  private

  def ends_at_after_starts_at
    return if starts_at.nil? || ends_at.nil?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after the start time")
  end

  def series_template_is_consistent
    return if training_series.blank? || training_template_id.blank?
    return if training_series.training_template_id == training_template_id

    errors.add(:training_template, "must match the series' template")
  end
end
