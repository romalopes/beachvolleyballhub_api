module Api
  module V1
    class WeatherAdvisorPreferencesController < ApplicationController
      before_action :ensure_authenticated_account

      def show
        render json: serialize(preference)
      end

      def update
        if preference.update(weather_advisor_preference_params)
          render json: serialize(preference)
        else
          render json: { errors: preference.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def destroy
        Current.user.account.weather_advisor_preference&.destroy!
        render json: default_preference
      end

      private

      def ensure_authenticated_account
        head :unauthorized unless Current.user&.account
      end

      def weather_advisor_preference_params
        # `conditions` and `wind_direction_preferences` are nested JSON objects
        # (dynamic keys: factor names / compass directions), so they must be
        # permitted as open hashes — `permit(:conditions)` alone drops them.
        params.require(:weather_advisor_preference).permit(
          *WeatherAdvisorPreference::WEIGHT_ATTRIBUTES,
          conditions: {},
          wind_direction_preferences: {}
        )
      end

      def serialize(record)
        base = record.as_json(only: WeatherAdvisorPreference::WEIGHT_ATTRIBUTES)
        base.merge(
          conditions: record.effective_conditions,
          wind_direction_preferences: record.effective_wind_direction_preferences
        )
      end

      def default_weights
        WeatherAdvisorPreference::DEFAULT_WEIGHTS.transform_keys { |factor| :"#{factor}_weight" }
      end

      def default_preference
        default_weights.merge(
          conditions: Weather::AdvisorPreferences.default_conditions.stringify_keys,
          wind_direction_preferences: Weather::AdvisorPreferences.default_directions.stringify_keys
        )
      end

      def preference
        @preference ||= Current.user.account.weather_advisor_preference ||
                        Current.user.account.create_weather_advisor_preference!
      end
    end
  end
end
