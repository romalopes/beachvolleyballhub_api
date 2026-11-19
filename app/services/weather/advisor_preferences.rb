# frozen_string_literal: true

module Weather
  module AdvisorPreferences
    DIRECTIONS = %w[N NE E SE S SW W NW].freeze
    DIRECTION_VALUES = %w[neutral bad very_bad].freeze
    DIRECTION_PENALTIES = { "neutral" => 0, "bad" => -10, "very_bad" => -20 }.freeze

    CONDITIONS = {
      temperature: { min_c: 5.0, ideal_min_c: 17.0, ideal_max_c: 28.0, max_c: 40.0 },
      wind: { ideal_max_kph: 10.0, comfortable_max_kph: 20.0, high_kph: 40.0 },
      rain: { preferred_max_percent: 20.0, comfortable_max_percent: 40.0, high_percent: 80.0 },
      uv: { preferred_max: 3.0, comfortable_max: 6.0, high: 10.0 },
      humidity: { preferred_max_percent: 60.0, comfortable_max_percent: 70.0, high_percent: 90.0 }
    }.freeze

    module_function

    def default_conditions
      CONDITIONS.deep_dup
    end

    def default_directions
      DIRECTIONS.index_with { "neutral" }
    end

    def normalize_conditions(value)
      source = value.respond_to?(:to_h) ? value.to_h : {}
      CONDITIONS.to_h do |factor, defaults|
        provided = source[factor] || source[factor.to_s] || {}
        [factor, defaults.merge(provided.to_h.symbolize_keys).stringify_keys]
      end
    end

    def normalize_directions(value)
      source = value.respond_to?(:to_h) ? value.to_h : {}
      source.to_h.each_with_object(default_directions) do |(direction, preference), result|
        direction = direction.to_s.upcase
        next unless DIRECTIONS.include?(direction)
        result[direction] = preference.to_s if DIRECTION_VALUES.include?(preference.to_s)
      end
    end

    def direction_for(direction:, beach_preferences:, general_preferences:)
      direction = direction.to_s.upcase
      return "neutral" unless DIRECTIONS.include?(direction)
      beach = normalize_directions(beach_preferences)
      general = normalize_directions(general_preferences)
      if beach_preferences.respond_to?(:key?) && (beach_preferences.key?(direction) || beach_preferences.key?(direction.to_sym))
        value = beach[direction]
        return value if DIRECTION_VALUES.include?(value)
      end
      general.fetch(direction, "neutral")
    end

    def compass_direction(degrees)
      value = Float(degrees, exception: false)
      return nil unless value&.finite? && value >= 0 && value <= 360
      return "N" if value == 360
      DIRECTIONS[((value + 22.5) / 45).floor % 8]
    end
  end
end