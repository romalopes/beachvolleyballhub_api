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

  def self.defaults
    DEFAULT_WEIGHTS
  end

  def weights
    DEFAULT_WEIGHTS.keys.to_h { |factor| [ factor, public_send(:"#{factor}_weight") ] }
  end

  private

  def weights_sum_to_100
    values = WEIGHT_ATTRIBUTES.map { |attribute| public_send(attribute) }
    return if values.any?(&:nil?)

    errors.add(:base, "Weights must sum to 100") unless values.sum == 100
  end
end
