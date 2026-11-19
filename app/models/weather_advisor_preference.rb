class WeatherAdvisorPreference < ApplicationRecord
  DEFAULT_WEIGHTS = {
    wind: 40,
    temperature: 20,
    rain: 25,
    uv: 5,
    humidity: 10
  }.freeze
  WEIGHT_ATTRIBUTES = DEFAULT_WEIGHTS.keys.map { |factor| :"#{factor}_weight" }.freeze

  belongs_to :account

  validates :account_id, uniqueness: true
  validates(*WEIGHT_ATTRIBUTES,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 })
  validate :weights_sum_to_100
  validate :conditions_are_valid
  validate :directions_are_valid

  def self.defaults
    DEFAULT_WEIGHTS
  end

  def weights
    DEFAULT_WEIGHTS.keys.to_h { |factor| [ factor, public_send(:"#{factor}_weight") ] }
  end

  def effective_conditions
    Weather::AdvisorPreferences.normalize_conditions(conditions)
  end

  def effective_wind_direction_preferences
    Weather::AdvisorPreferences.normalize_directions(wind_direction_preferences)
  end

  private

  def weights_sum_to_100
    values = WEIGHT_ATTRIBUTES.map { |attribute| public_send(attribute) }
    return if values.any?(&:nil?)

    errors.add(:base, "Weights must sum to 100") unless values.sum == 100
  end

  def conditions_are_valid
    normalized = Weather::AdvisorPreferences.normalize_conditions(conditions)
    all_numeric = true
    normalized.each_value do |values|
      values.each_value do |value|
        next if value.is_a?(Numeric) && value.finite?

        all_numeric = false
        errors.add(:conditions, "must contain numeric values")
      end
    end
    # Ordering comparisons only make sense once every value is numeric;
    # comparing a String against a Float would raise ArgumentError.
    return unless all_numeric

    temperature = normalized.fetch(:temperature)
    errors.add(:conditions, "temperature minimum must be below maximum") unless temperature.fetch("min_c") < temperature.fetch("max_c")
    errors.add(:conditions, "temperature ideal range is invalid") unless temperature.fetch("ideal_min_c") <= temperature.fetch("ideal_max_c")
  end

  def directions_are_valid
    value = wind_direction_preferences
    errors.add(:wind_direction_preferences, "must be an object") unless value.is_a?(Hash)
    return unless value.is_a?(Hash)
    value.each do |direction, preference|
      errors.add(:wind_direction_preferences, "contains an invalid direction") unless Weather::AdvisorPreferences::DIRECTIONS.include?(direction.to_s.upcase)
      errors.add(:wind_direction_preferences, "contains an invalid preference") unless Weather::AdvisorPreferences::DIRECTION_VALUES.include?(preference.to_s)
    end
  end
end
