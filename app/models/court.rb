class Court < ApplicationRecord
  STATUSES = %w[active archived].freeze

  belongs_to :location
  has_many :training_sessions, dependent: :restrict_with_error
  has_many :tournaments, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  before_validation { self.normalized_name = Location.normalize_name(name) }

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :location_id }
  validates :status, inclusion: { in: STATUSES }
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :coordinates_are_paired

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:name, :id) }

  def summary
    {
      id: id,
      location_id: location_id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      access_instructions: access_instructions,
      status: status
    }
  end

  private

  def coordinates_are_paired
    return if latitude.present? == longitude.present?

    errors.add(:base, "Latitude and longitude must both be present or both be blank")
  end
end
