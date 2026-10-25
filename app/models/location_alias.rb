class LocationAlias < ApplicationRecord
  belongs_to :location, inverse_of: :aliases

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  before_validation { self.normalized_name = Location.normalize_name(name) }

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :location_id }
end
