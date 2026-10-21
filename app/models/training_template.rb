# A reusable training definition: the "what we usually run" record.
#
# A template carries defaults only. It never owns scheduled occurrences; a
# TrainingSeries captures a snapshot of these defaults when the recurrence is
# created, so editing a template afterwards cannot rewrite history. Templates
# are archived rather than deleted because sessions and series may still refer
# to them.
#
# `created_by` is audit only, exactly like TrainingSession#created_by: it is not
# an ownership boundary. Management remains role-based (ContentAuthorization).
class TrainingTemplate < ApplicationRecord
  STATUSES = %w[active archived].freeze
  VISIBILITIES = %w[shared private].freeze

  belongs_to :organisation, optional: true
  belongs_to :group, optional: true
  belongs_to :coach_profile, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  # A template that has been used is history; deleting it would leave series
  # and sessions pointing at nothing. Archive instead.
  has_many :training_series, dependent: :restrict_with_error, inverse_of: :training_template
  has_many :training_sessions, dependent: :restrict_with_error, inverse_of: :training_template

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :visibility, presence: true, inclusion: { in: VISIBILITIES }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :group_belongs_to_the_organisation,
           if: -> { organisation_id.present? && group_id.present? }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def archived?
    status == "archived"
  end

  # The snapshot a series stores at creation time. Keys are symbols so callers
  # can merge/override them without caring about JSON string keys.
  def defaults_for_series
    {
      title: name,
      description: description,
      organisation_id: organisation_id,
      group_id: group_id,
      coach_profile_id: coach_profile_id,
      location: location,
      location_detail: location_detail,
      level: level,
      capacity: capacity,
      duration_minutes: duration_minutes,
      visibility: visibility
    }
  end

  # Human-readable location for lists. The free-text `location` stays the
  # source of truth until the Location feature introduces court records.
  def location_summary
    [ location, location_detail ].compact_blank.join(" · ").presence
  end

  private

  # A template's organisation and group must describe the same club. The group
  # may have no organisation (legacy rows), in which case there is nothing to
  # contradict.
  def group_belongs_to_the_organisation
    return if group.nil? || group.organisation_id.nil?

    return if group.organisation_id == organisation_id

    errors.add(:group, "does not belong to the selected organisation")
  end
end
