# A weekly recurrence definition plus the training defaults captured when the
# series was created.
#
# The series drives generation and grouping only. Every occurrence is an
# independent TrainingSession; changing the rule is done by splitting the
# series, never by rewriting already-generated rows. `stopped` means "generate
# no more occurrences" and deliberately leaves existing sessions untouched.
#
# Time handling: the application default zone is UTC, so a series always stores
# an explicit IANA `time_zone`. `local_start_time` is a wall-clock time in that
# zone; the expander converts each date to UTC.
class TrainingSeries < ApplicationRecord
  FREQUENCIES = %w[weekly].freeze
  STATUSES = %w[active stopped].freeze
  WEEKDAYS = %w[mon tue wed thu fri sat sun].freeze

  belongs_to :training_template
  belongs_to :organisation, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :training_sessions,
           foreign_key: :training_series_id,
           dependent: :restrict_with_error,
           inverse_of: :training_series

  before_validation :normalize_weekdays

  validates :frequency, presence: true, inclusion: { in: FREQUENCIES }
  validates :interval, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :starts_on, presence: true
  validates :ends_on, presence: true
  validates :local_start_time, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :time_zone, presence: true
  validate :ends_on_is_not_before_starts_on
  validate :weekdays_are_supported
  validate :time_zone_is_recognised
  validate :organisation_matches_the_template,
           if: -> { organisation_id.present? && training_template&.organisation_id.present? }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def stopped?
    status == "stopped"
  end

  # The IANA zone as an ActiveSupport zone object. Validation guarantees it is
  # recognised, but callers still get nil for a corrupt row rather than an
  # exception.
  def time_zone_object
    ActiveSupport::TimeZone[time_zone]
  end

  # Snapshot of the template defaults, symbolised for merging.
  def defaults
    (defaults_snapshot || {}).deep_symbolize_keys
  end

  # First date the next generation run should consider. `generated_through` is
  # exclusive: it records the last date that has been generated.
  def next_generation_start
    return starts_on if generated_through.blank?

    [ generated_through + 1.day, starts_on ].max
  end

  # A series is finished for display purposes once its window has passed. This
  # does not change `status`; only stopping does that.
  def completed?
    ends_on.present? && ends_on < Date.current
  end

  private

  def normalize_weekdays
    self.weekdays = Array(weekdays).map { |day| day.to_s.strip.downcase }
                                   .reject(&:blank?)
                                   .uniq
  end

  def ends_on_is_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end

  def weekdays_are_supported
    days = Array(weekdays)
    if days.empty?
      errors.add(:weekdays, "must include at least one weekday")
      return
    end

    invalid = days - WEEKDAYS
    return if invalid.empty?

    errors.add(:weekdays, "contains unsupported weekdays: #{invalid.join(', ')}")
  end

  def time_zone_is_recognised
    return if time_zone.blank?
    return if ActiveSupport::TimeZone[time_zone].present?

    errors.add(:time_zone, "is not a recognised time zone")
  end

  def organisation_matches_the_template
    return if training_template.organisation_id == organisation_id

    errors.add(:organisation, "must match the template's organisation")
  end
end
