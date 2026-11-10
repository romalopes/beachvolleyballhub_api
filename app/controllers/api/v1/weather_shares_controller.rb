module Api
  module V1
    class WeatherSharesController < ApplicationController
      before_action :require_authentication, only: [:create]
      before_action :set_snapshot, only: [:destroy, :metadata]

      # POST /api/v1/weather_shares
      def create
        latitude = parse_coordinate(:lat, -90..90)
        return if performed?

        longitude = parse_coordinate(:lon, -180..180)
        return if performed?

        location_name = params[:location_name].to_s.strip
        if location_name.blank?
          render json: { error: "location_name is required" }, status: :unprocessable_entity
          return
        end

        forecast_target_time = parse_forecast_target_time
        return if performed? && forecast_target_time.nil?

        # Fetch weather data for the snapshot
        forecast = WeatherApi.fetch_forecast(latitude, longitude).deep_dup

        # Use the forecast target time if provided, otherwise use current
        if forecast_target_time
          forecast[:current] = forecast[:hourly]&.find { |h| h[:time_epoch] == forecast_target_time.to_i } || forecast[:current]
        end

        # Calculate volleyball assessment
        volleyball = personalized_assessment(forecast)

        # Build the snapshot
        snapshot = Current.user.account.weather_share_snapshots.build(
          latitude: latitude,
          longitude: longitude,
          location_name: location_name,
          forecast_target_time: forecast_target_time,
          timezone: forecast[:location]&.dig(:timezone),
          weather_data: forecast,
          volleyball_score: volleyball[:score],
          volleyball_label: volleyball[:label],
          volleyball_warnings: volleyball[:warnings],
          volleyball_advice: volleyball[:advice],
          volleyball_safety_override: volleyball[:safety_override]
        )

        if snapshot.save
          # TODO: Phase 3/4 - Trigger image generation job
          # WeatherShareImageGeneratorJob.perform_later(snapshot)

          render json: {
            public_token: snapshot.public_token,
            public_url: snapshot.public_url,
            image_url: snapshot.image_url,
            expires_at: snapshot.expires_at&.iso8601,
            created_at: snapshot.created_at.iso8601
          }, status: :created
        else
          render json: { errors: snapshot.errors.full_messages }, status: :unprocessable_entity
        end
      rescue WeatherApi::ConfigurationError => error
        render json: { error: error.message }, status: :service_unavailable
      rescue WeatherApi::ProviderError => error
        Rails.logger.warn("WeatherAPI request failed: #{error.message}")
        render json: { error: "Weather forecast is temporarily unavailable" }, status: :bad_gateway
      end

      # DELETE /api/v1/weather_shares/:public_token
      def destroy
        authorize_snapshot_owner!
        return if performed?

        @snapshot.revoke!
        head :no_content
      end

      # GET /api/v1/weather_shares/:public_token/metadata (public)
      def metadata
        unless @snapshot&.active?
          render json: { error: "Share not found or has expired" }, status: :not_found
          return
        end

        render json: {
          public_token: @snapshot.public_token,
          location_name: @snapshot.location_name,
          latitude: @snapshot.latitude,
          longitude: @snapshot.longitude,
          forecast_target_time: @snapshot.forecast_target_time&.iso8601,
          timezone: @snapshot.timezone,
          volleyball: @snapshot.volleyball_assessment,
          image_url: @snapshot.image_url,
          canonical_url: @snapshot.public_url,
          expires_at: @snapshot.expires_at&.iso8601,
          created_at: @snapshot.created_at.iso8601
        }
      end

      private

      def set_snapshot
        @snapshot = WeatherShareSnapshot.find_by(public_token: params[:public_token])
        render json: { error: "Share not found" }, status: :not_found unless @snapshot
      end

      def authorize_snapshot_owner!
        return if @snapshot&.account_id == Current.user&.account&.id

        render json: { error: "Not authorized" }, status: :forbidden
      end

      def parse_coordinate(name, range)
        value = Float(params[name], exception: false)
        return value if value&.finite? && range.cover?(value)

        render json: { error: "#{name} must be a number between #{range.begin} and #{range.end}" },
               status: :unprocessable_entity
        nil
      end

      def parse_forecast_target_time
        return nil unless params[:forecast_target_time].present?

        parsed = Time.zone.parse(params[:forecast_target_time])
        return parsed if parsed

        render json: { error: "forecast_target_time must be a valid ISO8601 timestamp" },
               status: :unprocessable_entity
        nil
      end

      def personalized_assessment(forecast)
        preference = Current.user&.account&.weather_advisor_preference
        Weather::VolleyballAdvisor.assess(
          current: forecast[:current] || forecast["current"],
          rain_chance_percent: Array(forecast[:forecast] || forecast["forecast"]).first&.then do |day|
            day[:rain_chance_percent] || day["rain_chance_percent"]
          end,
          weights: preference&.weights
        )
      end
    end
  end
end