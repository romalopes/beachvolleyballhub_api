class WeatherAdvisorLocationPreference < ApplicationRecord
  DIRECTIONS = Weather::AdvisorPreferences::DIRECTIONS
  VALUES = Weather::AdvisorPreferences::DIRECTION_VALUES

  belongs_to :account
  belongs_to :location

  validates :account_id, uniqueness: { scope: :location_id }
  validate :valid_direction_preferences

  def normalized_preferences
    Weather::AdvisorPreferences.normalize_directions(wind_direction_preferences)
  end

  private

  def valid_direction_preferences
    value = wind_direction_preferences
    errors.add(:wind_direction_preferences, "must be an object") unless value.is_a?(Hash)
    return unless value.is_a?(Hash)
    value.each do |direction, preference|
      errors.add(:wind_direction_preferences, "contains an invalid direction") unless DIRECTIONS.include?(direction.to_s.upcase)
      errors.add(:wind_direction_preferences, "contains an invalid preference") unless VALUES.include?(preference.to_s)
    end
  end
end