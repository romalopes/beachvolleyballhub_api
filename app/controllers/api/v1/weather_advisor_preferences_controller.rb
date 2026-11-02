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
        render json: default_weights
      end

      private

      def ensure_authenticated_account
        head :unauthorized unless Current.user&.account
      end

      def weather_advisor_preference_params
        params.require(:weather_advisor_preference)
              .permit(*WeatherAdvisorPreference::WEIGHT_ATTRIBUTES)
      end

      def serialize(record)
        record.as_json(only: WeatherAdvisorPreference::WEIGHT_ATTRIBUTES)
      end

      def default_weights
        WeatherAdvisorPreference::DEFAULT_WEIGHTS.transform_keys { |factor| :"#{factor}_weight" }
      end

      def preference
        @preference ||= Current.user.account.weather_advisor_preference ||
                        Current.user.account.create_weather_advisor_preference!
      end
    end
  end
end