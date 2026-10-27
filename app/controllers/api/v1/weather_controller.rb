module Api
  module V1
    class WeatherController < ApplicationController
      def show
        latitude = parse_coordinate(:lat, -90..90)
        return if performed?

        longitude = parse_coordinate(:lon, -180..180)
        return if performed?

        render json: WeatherApi.fetch_forecast(latitude, longitude)
      rescue WeatherApi::ConfigurationError => error
        render json: { error: error.message }, status: :service_unavailable
      rescue WeatherApi::ProviderError => error
        Rails.logger.warn("WeatherAPI request failed: #{error.message}")
        render json: { error: "Weather forecast is temporarily unavailable" }, status: :bad_gateway
      end

      private

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