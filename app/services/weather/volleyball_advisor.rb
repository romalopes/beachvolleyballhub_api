# frozen_string_literal: true
require_relative "advisor_preferences"
require_relative "direction_preference_resolver"

module Weather
  class VolleyballAdvisor
    WEIGHTS = { wind: 0.40, temperature: 0.20, rain: 0.25, uv: 0.05, humidity: 0.10 }.freeze
    LABELS = [[85, "Excellent"], [70, "Good"], [50, "Fair"], [30, "Poor"], [0, "Unsuitable"]].freeze

    class << self
      def assess(current:, rain_chance_percent: nil, weights: nil, conditions: nil,
                 wind_direction_preferences: nil, beach_wind_direction_preferences: nil)
        new(current:, rain_chance_percent:, weights:, conditions:, wind_direction_preferences:,
            beach_wind_direction_preferences:).assess
      end
    end

    def initialize(current:, rain_chance_percent: nil, weights: nil, conditions: nil,
                   wind_direction_preferences: nil, beach_wind_direction_preferences: nil)
      @current = current.is_a?(Hash) ? current : {}
      @rain_chance = number(rain_chance_percent)
      @weights = weights.nil? ? WEIGHTS : normalize_weights(weights)
      @conditions = AdvisorPreferences.normalize_conditions(conditions)
      @general_directions = AdvisorPreferences.normalize_directions(wind_direction_preferences)
      @beach_directions = beach_wind_direction_preferences
    end

    def assess
      rating = score
      { score: rating, label: label_for(rating), advice:, warnings:, safety_override: warnings.any? }
    end

    def score
      factor_scores = { wind: wind_score, temperature: temperature_score, rain: rain_score, uv: uv_score, humidity: humidity_score }
      available = factor_scores.filter { |factor, value| !value.nil? && @weights.fetch(factor).positive? }
      measured_weight = available.keys.sum { |factor| @weights.fetch(factor) }
      return nil unless measured_weight.positive?

      (available.sum { |factor, value| value * @weights.fetch(factor) } / measured_weight).round
    end

    def normalize_weights(weights)
      normalized = weights.to_h.transform_keys(&:to_sym)
      raise ArgumentError, "weights must contain exactly: #{WEIGHTS.keys.join(', ')}" unless normalized.keys.sort == WEIGHTS.keys.sort
      normalized.each { |factor, value| raise ArgumentError, "invalid weight for #{factor}" unless value.is_a?(Numeric) && value.finite? && value.between?(0, 100) }
      raise ArgumentError, "weights must sum to 100" unless normalized.values.sum == 100
      normalized.transform_values { |value| value / 100.0 }.freeze
    end

    def label_for(rating)
      return "Unknown" if rating.nil?

      LABELS.find { |minimum, _| rating >= minimum }.last
    end

    def wind_score
      wind = number(@current[:wind_kph] || @current["wind_kph"])
      return nil if wind.nil?
      thresholds = @conditions.fetch(:wind)
      base = if wind <= thresholds.fetch("ideal_max_kph") then 100
             elsif wind <= thresholds.fetch("comfortable_max_kph") then 85
             elsif wind <= 30 then 65
             elsif wind <= thresholds.fetch("high_kph") then 40
             else 15 end
      gust = number(@current[:wind_gust_kph] || @current["wind_gust_kph"])
      base -= 10 if gust && gust - wind > 15
      direction = @current[:wind_direction] || @current["wind_direction"]
      direction ||= AdvisorPreferences.compass_direction(@current[:wind_degree] || @current["wind_degree"])
      preference = DirectionPreferenceResolver.resolve(direction:, general: @general_directions, beach: @beach_directions)
      (base + DirectionPreferenceResolver.penalty(preference)).clamp(0, 100)
    end

    def temperature_score
      temperature = number(@current[:feels_like_c] || @current["feels_like_c"]) || number(@current[:temperature_c] || @current["temperature_c"])
      return nil if temperature.nil?
      t = @conditions.fetch(:temperature)
      if temperature <= t.fetch("min_c") then 15
      elsif temperature < t.fetch("ideal_min_c") then 35 + ((temperature - t.fetch("min_c")) / (t.fetch("ideal_min_c") - t.fetch("min_c")) * 45).round
      elsif temperature <= t.fetch("ideal_max_c") then 100
      elsif temperature < t.fetch("max_c") then [100 - ((temperature - t.fetch("ideal_max_c")) / (t.fetch("max_c") - t.fetch("ideal_max_c")) * 80).round, 20].max
      else 20 end
    end

    def rain_score
      chance = @rain_chance
      if chance.nil?
        precipitation = number(@current[:precipitation_mm] || @current["precipitation_mm"])
        chance = case precipitation when nil then nil when 0...0.5 then 10 when 0.5...2.5 then 40 when 2.5...7.6 then 65 else 90 end
      end
      return nil if chance.nil?
      t = @conditions.fetch(:rain)
      if chance <= t.fetch("preferred_max_percent") then 100
      elsif chance <= t.fetch("comfortable_max_percent") then 80
      elsif chance <= 60 then 55
      elsif chance <= t.fetch("high_percent") then 30
      else 10 end
    end

    def uv_score
      uv = number(@current[:uv_index] || @current["uv_index"])
      return nil if uv.nil?
      t = @conditions.fetch(:uv)
      if uv < t.fetch("preferred_max") then 100 elsif uv < t.fetch("comfortable_max") then 90 elsif uv < 8 then 70 elsif uv <= t.fetch("high") then 45 else 25 end
    end

    def humidity_score
      humidity = number(@current[:humidity_percent] || @current["humidity_percent"])
      return nil if humidity.nil?
      t = @conditions.fetch(:humidity)
      if humidity <= t.fetch("preferred_max_percent") then 100 elsif humidity <= t.fetch("comfortable_max_percent") then 90 elsif humidity <= 80 then 75 elsif humidity <= t.fetch("high_percent") then 50 else 25 end
    end

    def advice
      [wind_advice, gust_advice, temperature_advice, rain_advice, uv_advice, humidity_advice].compact
    end
    def wind_advice
      wind = number(@current[:wind_kph] || @current["wind_kph"]); return nil if wind.nil?
      wind <= 10 ? "Calm wind: ideal for precision and controlled ball-placement drills." : wind <= 20 ? "Light to moderate wind: generally good with mild shot adjustments." : wind <= 30 ? "Challenging wind: practise wind-adjusted serving, passing and setting." : wind <= 40 ? "Difficult wind: the coach should assess court conditions and gusts." : "Very strong wind: consider postponing and evaluate local hazards."
    end
    def gust_advice
      wind = number(@current[:wind_kph] || @current["wind_kph"]); gust = number(@current[:wind_gust_kph] || @current["wind_gust_kph"]); wind && gust && gust - wind > 15 ? "Gusty conditions: allow extra space and expect sudden ball movement." : nil
    end
    def temperature_advice
      temperature = number(@current[:feels_like_c] || @current["feels_like_c"]) || number(@current[:temperature_c] || @current["temperature_c"]); return nil if temperature.nil?
      temperature >= 32 ? "Hot conditions: hydrate frequently and take shade breaks." : temperature <= 10 ? "Cold conditions: warm up thoroughly and maintain body temperature." : nil
    end
    def rain_advice; return nil if @rain_chance.nil? || @rain_chance < 40; @rain_chance > 80 ? "Heavy rain is likely: prepare to postpone or move the session." : "Rain is possible: monitor the court surface and have a backup plan." end
    def uv_advice; uv = number(@current[:uv_index] || @current["uv_index"]); uv && uv >= 6 ? "UV is elevated: use sunscreen, a hat and sunglasses." : nil end
    def humidity_advice; humidity = number(@current[:humidity_percent] || @current["humidity_percent"]); humidity && humidity >= 80 ? "High humidity: schedule additional hydration and recovery breaks." : nil end
    def warnings
      [wind_warning, heat_warning, rain_warning, uv_warning].compact
    end
    def wind_warning; wind = number(@current[:wind_kph] || @current["wind_kph"]); gust = number(@current[:wind_gust_kph] || @current["wind_gust_kph"]); (wind && wind > 40) || (gust && gust > 40) ? "Dangerous gusts: postpone play and secure equipment." : nil end
    def heat_warning; temperature = number(@current[:feels_like_c] || @current["feels_like_c"]) || number(@current[:temperature_c] || @current["temperature_c"]); temperature && temperature >= 40 ? "Extreme heat: high risk of heat stress; avoid strenuous play." : nil end
    def rain_warning; @rain_chance && @rain_chance > 80 ? "Heavy rain expected: sand and surrounding surfaces may be unsafe." : nil end
    def uv_warning; uv = number(@current[:uv_index] || @current["uv_index"]); uv && uv > 10 ? "Extreme UV: limit time in direct sun." : nil end
    def number(value); converted = Float(value, exception: false); converted if converted&.finite? end
  end
end
