class Location < ApplicationRecord
  require "digest"

  include Sluggable
  source_column :name

  TYPES = %w[beach sports_venue park indoor club other].freeze
  STATUSES = %w[active archived merged].freeze
  VERIFICATION_STATUSES = %w[proposed verified rejected].freeze
  GEOCODING_STATUSES = %w[not_requested pending resolved failed manual].freeze

  belongs_to :proposed_by_account, class_name: "Account", optional: true
  belongs_to :verified_by_account, class_name: "Account", optional: true
  belongs_to :merged_into, class_name: "Location", optional: true

  has_many :aliases, class_name: "LocationAlias", dependent: :destroy, inverse_of: :location
  has_many :courts, dependent: :restrict_with_error
  has_many :organisation_locations, dependent: :restrict_with_error
  has_many :organisations, through: :organisation_locations
  has_many :default_organisations, class_name: "Organisation", foreign_key: :default_location_id,
             dependent: :restrict_with_error, inverse_of: :default_location
  has_many :default_groups, class_name: "Group", foreign_key: :default_location_id,
             dependent: :restrict_with_error, inverse_of: :default_location
  has_many :training_sessions, foreign_key: :location_id, dependent: :restrict_with_error,
             inverse_of: :canonical_location
  has_many :tournaments, dependent: :restrict_with_error

  accepts_nested_attributes_for :aliases, allow_destroy: true

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  normalizes :country_code, with: ->(value) { value.to_s.strip.upcase.presence }

  before_validation :set_normalized_name
  before_validation :synchronize_lifecycle

  validates :name, presence: true, length: { maximum: 160 }
  validates :normalized_name, presence: true
  validates :location_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
  validates :geocoding_status, inclusion: { in: GEOCODING_STATUSES }
  validates :country_code, length: { is: 2 }, allow_blank: true
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :coordinates_are_paired
  validate :merge_target_is_valid
  validate :verified_state_has_provenance

  scope :active, -> { where(status: "active") }
  scope :selectable, -> { active.where(verification_status: "verified") }
  scope :usable_by, lambda { |account|
    verified = active.where(verification_status: "verified")
    next verified if account.blank?

    active.where(verification_status: "verified")
      .or(active.where(verification_status: "proposed", proposed_by_account_id: account.id))
  }
  scope :ordered, -> { order(:name, :id) }

  def self.normalize_name(value)
    I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def self.search(term)
    normalized = normalize_name(term)
    return all if normalized.blank?

    normalized_pattern = "%#{sanitize_sql_like(normalized)}%"
    raw_pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    left_joins(:aliases)
      .where(
        "locations.normalized_name ILIKE :normalized OR location_aliases.normalized_name ILIKE :normalized OR locations.locality ILIKE :raw",
        normalized: normalized_pattern,
        raw: raw_pattern
      )
      .distinct
  end

  def selectable?
    status == "active" && verification_status == "verified"
  end

  def usable_by?(account)
    return false unless status == "active"
    return true if verification_status == "verified"

    verification_status == "proposed" && account.present? && proposed_by_account_id == account.id
  end

  def geocodable?
    formatted_address.present? ||
      (name.present? && country_code.present? && (locality.present? || administrative_area.present?))
  end

  def geocoding_query
    [ name, formatted_address, locality, administrative_area, country_code ]
      .filter_map { |value| value.to_s.strip.presence }
      .join(", ")
      .squish
  end

  def geocoding_fingerprint
    Digest::SHA256.hexdigest(geocoding_query.downcase)
  end

  def geocoding_job_applicable?(expected_fingerprint)
    status == "active" &&
      geocoding_status == "pending" &&
      coordinate_source != "manual" &&
      geocodable? &&
      geocoding_fingerprint == expected_fingerprint
  end

  def coordinates?
    latitude.present? && longitude.present?
  end

  def map_url
    return nil unless coordinates?

    "https://www.google.com/maps/search/?api=1&query=#{latitude},#{longitude}"
  end

  def verify!(account)
    update!(verification_status: "verified", verified_by_account: account, verified_at: Time.current)
  end

  def reject!
    update!(verification_status: "rejected", verified_by_account: nil, verified_at: nil)
  end

  def archive!
    update!(status: "archived", archived_at: Time.current)
  end

  def activate!
    raise ActiveRecord::RecordInvalid, self if status == "merged"

    update!(status: "active", archived_at: nil)
  end

  def summary
    {
      id: id,
      name: name,
      slug: slug,
      location_type: location_type,
      formatted_address: formatted_address,
      locality: locality,
      administrative_area: administrative_area,
      country_code: country_code,
      timezone: timezone,
      latitude: latitude,
      longitude: longitude,
      status: status,
      verification_status: verification_status,
      geocoding_status: geocoding_status,
      coordinate_source: coordinate_source,
      map_url: map_url
    }
  end

  private

  def set_normalized_name
    self.normalized_name = self.class.normalize_name(name)
  end

  def synchronize_lifecycle
    self.archived_at ||= Time.current if status == "archived"
    self.archived_at = nil if status == "active"
  end

  def coordinates_are_paired
    return if latitude.present? == longitude.present?

    errors.add(:base, "Latitude and longitude must both be present or both be blank")
  end

  def merge_target_is_valid
    return if merged_into_id.blank?

    errors.add(:merged_into, "cannot be itself") if persisted? && merged_into_id == id
    errors.add(:status, "must be merged when a merge target is set") unless status == "merged"
  end

  def verified_state_has_provenance
    return unless verification_status == "verified"
    return if verified_at.present? && (verified_by_account_id.present? || source.present?)

    errors.add(:verification_status, "requires verification provenance and time")
  end
end
