module Api
  module V1
    class GeocodingController < ApplicationController
      def show
        query = params[:q].to_s.strip
        if query.blank?
          return render json: { error: "q parameter is required" },
                        status: :unprocessable_entity
        end

        result = Geocoding::Client.new.search(query)
        if result.nil?
          return render json: { error: "No matching location was found" },
                        status: :not_found
        end

        render json: {
          latitude: result.latitude,
          longitude: result.longitude,
          formatted_address: result.formatted_address,
          locality: result.locality,
          administrative_area: result.administrative_area,
          country_code: result.country_code
        }
      rescue Geocoding::ConfigurationError => error
        render json: { error: error.message }, status: :service_unavailable
      rescue Geocoding::TransientError, Geocoding::ProviderError => error
        Rails.logger.warn("Geocoding request failed: #{error.message}")
        render json: { error: "Location lookup is temporarily unavailable" },
               status: :bad_gateway
      end
    end
  end
end