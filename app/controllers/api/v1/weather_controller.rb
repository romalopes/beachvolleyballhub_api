module Api
  module V1
    class WeatherController < ApplicationController
      def show
        latitude = parse_coordinate(:lat, -90..90)
        return if performed?

        longitude = parse_coordinate(:lon, -180..180)
        return if performed?

        forecast = WeatherApi.fetch_forecast(latitude, longitude).deep_dup
        forecast[:volleyball] = personalized_assessment(forecast)
        forecast[forecast.key?(:hourly) ? :hourly : "hourly"] = hourly_with_assessments(forecast)
        render json: forecast
      rescue WeatherApi::ConfigurationError => error
        render json: { error: error.message }, status: :service_unavailable
      rescue WeatherApi::ProviderError => error
        Rails.logger.warn("WeatherAPI request failed: #{error.message}")
        render json: { error: "Weather forecast is temporarily unavailable" }, status: :bad_gateway
      end

      private

      # Each forecast hour gets its own advisor assessment so the UI can show
      # the suitability for any time in the three-day forecast window. The
      # signed-in account's preferences apply here exactly as they do to `current`.
      def hourly_with_assessments(forecast)
        hourly = forecast[:hourly] || forecast["hourly"]
        return [] unless hourly.is_a?(Array)

        pref = current_preference
        weights = pref&.weights
        conditions = pref&.effective_conditions
        general_directions = pref&.effective_wind_direction_preferences
        hourly.filter_map do |hour|
          next unless hour.is_a?(Hash)

          hour.merge(
            volleyball: Weather::VolleyballAdvisor.assess(
              current: hour,
              rain_chance_percent: hour[:rain_chance_percent] || hour["rain_chance_percent"],
              weights: weights,
              conditions: conditions,
              wind_direction_preferences: general_directions
            )
          )
        end
      end

      def personalized_assessment(forecast)
        pref = current_preference
        Weather::VolleyballAdvisor.assess(
          current: forecast[:current] || forecast["current"],
          rain_chance_percent: Array(forecast[:forecast] || forecast["forecast"]).first&.then do |day|
            day[:rain_chance_percent] || day["rain_chance_percent"]
          end,
          weights: pref&.weights,
          conditions: pref&.effective_conditions,
          wind_direction_preferences: pref&.effective_wind_direction_preferences
        )
      end

      def current_preference
        Current.user&.account&.weather_advisor_preference
      end

      def parse_coordinate(name, range)
        value = Float(params[name], exception: false)
        return value if value&.finite? && range.cover?(value)

        render json: { error: "#{name} must be a number between #{range.begin} and #{range.end}" },
               status: :unprocessable_entity
        nil
      end
    end
  end
end
