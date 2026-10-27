# frozen_string_literal: true

module Weather
  # Deterministic beach-volleyball playing-suitability heuristic (Phase 3).
  #
  # This is a coaching aid, NOT a certified safety rating: warnings are shown
  # independently of the score and the result never claims conditions are
  # "safe to play". Thresholds are product heuristics and may be tuned.
  #
  # Factor weights follow the implementation plan: wind 40%, temperature 20%,
  # rain 25%, UV 5%, humidity 10%. Missing measurements are dropped and the
  # remaining weights renormalised; a fully unknown assessment scores nil.
  class VolleyballAdvisor
    WEIGHTS = { wind: 0.40, temperature: 0.20, rain: 0.25, uv: 0.05, humidity: 0.10 }.freeze
    LABELS = [[85, "Excellent"], [70, "Good"], [50, "Fair"], [30, "Poor"], [0, "Unsuitable"]].freeze

    class << self
      def assess(current:, rain_chance_percent: nil)
        new(current: current, rain_chance_percent: rain_chance_percent).assess
      end
    end

    def initialize(current:, rain_chance_percent: nil)
      @current = current.is_a?(Hash) ? current : {}
      @rain_chance = number(rain_chance_percent)
    end

    def assess
      rating = score
      {
        score: rating,
        label: label_for(rating),
        advice: advice,
        warnings: warnings,
        safety_override: warnings.any?
      }
    end

    private

    def score
      factors = WEIGHTS.filter_map do |factor, weight|
        value = send(:"#{factor}_score")
        value ? [value * weight, weight] : nil
      end
      return nil if factors.empty?

      (factors.sum { |(weighted, _)| weighted } / factors.sum { |(_, weight)| weight }).round
    end

    def label_for(rating)
      return "Unknown" if rating.nil?

      LABELS.find { |minimum, _| rating >= minimum }.last
    end

    def wind_score
      wind = number(@current[:wind_kph])
      return nil if wind.nil?

      base =
        if wind <= 10 then 100
        elsif wind <= 20 then 85
        elsif wind <= 30 then 65
        elsif wind <= 40 then 40
        else 15
        end

      gust = number(@current[:wind_gust_kph])
      base -= 10 if gust && gust - wind > 15
      base.clamp(0, 100)
    end

    def temperature_score
      temperature = number(@current[:feels_like_c]) || number(@current[:temperature_c])
      return nil if temperature.nil?

      if temperature <= 5 then 15
      elsif temperature <= 10 then 35
      elsif temperature <= 15 then 60
      elsif temperature <= 17 then 80
      elsif temperature <= 28 then 100
      elsif temperature <= 31 then 85
      elsif temperature <= 34 then 65
      elsif temperature <= 37 then 40
      else 20
      end
    end

    def rain_score
      chance = @rain_chance
      if chance.nil?
        precipitation = number(@current[:precipitation_mm])
        chance =
          case precipitation
          when nil then nil
          when 0...0.5 then 10
          when 0.5...2.5 then 40
          when 2.5...7.6 then 65
          else 90
          end
      end
      return nil if chance.nil?

      if chance <= 20 then 100
      elsif chance <= 40 then 80
      elsif chance <= 60 then 55
      elsif chance <= 80 then 30
      else 10
      end
    end

    def uv_score
      uv = number(@current[:uv_index])
      return nil if uv.nil?

      if uv < 3 then 100
      elsif uv < 6 then 90
      elsif uv < 8 then 70
      elsif uv <= 10 then 45
      else 25
      end
    end

    def humidity_score
      humidity = number(@current[:humidity_percent])
      return nil if humidity.nil?

      if humidity <= 60 then 100
      elsif humidity <= 70 then 90
      elsif humidity <= 80 then 75
      elsif humidity <= 90 then 50
      else 25
      end
    end

    def advice
      [wind_advice, gust_advice, temperature_advice, rain_advice, uv_advice, humidity_advice].compact
    end

    def wind_advice
      wind = number(@current[:wind_kph])
      return nil if wind.nil?

      if wind <= 10
        "Calm wind: ideal for precision and controlled ball-placement drills."
      elsif wind <= 20
        "Light to moderate wind: generally good with mild shot adjustments."
      elsif wind <= 30
        "Challenging wind: practise wind-adjusted serving, passing and setting."
      elsif wind <= 40
        "Difficult wind: the coach should assess court conditions and gusts."
      else
        "Very strong wind: consider postponing and evaluate local hazards."
      end
    end

    def gust_advice
      wind = number(@current[:wind_kph])
      gust = number(@current[:wind_gust_kph])
      return nil unless wind && gust && gust - wind > 15

      "Gusty conditions: allow extra space and expect sudden ball movement."
    end

    def temperature_advice
      temperature = number(@current[:feels_like_c]) || number(@current[:temperature_c])
      return nil if temperature.nil?

      if temperature >= 32
        "Hot conditions: hydrate frequently and take shade breaks."
      elsif temperature <= 10
        "Cold conditions: warm up thoroughly and maintain body temperature."
      end
    end

    def rain_advice
      return nil if @rain_chance.nil? || @rain_chance < 40

      if @rain_chance > 80
        "Heavy rain is likely: prepare to postpone or move the session."
      else
        "Rain is possible: monitor the court surface and have a backup plan."
      end
    end

    def uv_advice
      uv = number(@current[:uv_index])
      return nil if uv.nil? || uv < 6

      "UV is elevated: use sunscreen, a hat and sunglasses."
    end

    def humidity_advice
      humidity = number(@current[:humidity_percent])
      return nil if humidity.nil? || humidity < 80

      "High humidity: schedule additional hydration and recovery breaks."
    end

    def warnings
      [wind_warning, heat_warning, rain_warning, uv_warning].compact
    end

    def wind_warning
      wind = number(@current[:wind_kph])
      gust = number(@current[:wind_gust_kph])
      return nil unless (wind && wind > 40) || (gust && gust > 40)

      "Dangerous gusts: postpone play and secure equipment."
    end

    def heat_warning
      temperature = number(@current[:feels_like_c]) || number(@current[:temperature_c])
      return nil unless temperature && temperature >= 40

      "Extreme heat: high risk of heat stress; avoid strenuous play."
    end

    def rain_warning
      return nil unless @rain_chance && @rain_chance > 80

      "Heavy rain expected: sand and surrounding surfaces may be unsafe."
    end

    def uv_warning
      uv = number(@current[:uv_index])
      return nil unless uv && uv > 10

      "Extreme UV: limit time in direct sun."
    end

    def number(value)
      converted = Float(value, exception: false)
      converted if converted&.finite?
    end
  end
end