module Api
  module V1
    # The signed-in account's notification channel preferences.
    #
    # A missing row is materialised on first read/write with the column defaults
    # (in-app on, email off), so the SPA always receives a complete payload and
    # no account needs a backfill.
    class NotificationPreferencesController < ApplicationController
      # The API base controller is public by default; preferences are personal.
      before_action :require_authentication

      def show
        render json: serialize(preference)
      end

      def update
        if preference.update(preference_params)
          render json: serialize(preference)
        else
          render json: { errors: preference.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def preference
        @preference ||= Current.user.account.notification_preference ||
                        Current.user.account.create_notification_preference!
      end

      def preference_params
        params.require(:notification_preference)
              .permit(:in_app_enabled, :email_enabled, :email_cadence, muted_event_types: [])
      end

      def serialize(record)
        record.as_json(only: %i[in_app_enabled email_enabled email_cadence muted_event_types])
      end
    end
  end
end
