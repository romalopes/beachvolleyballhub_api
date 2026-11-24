module Api
  module V1
    module Admin
      # Admin-only global configuration endpoint backing the Configuration page.
      #
      # Exposes runtime settings stored in app_settings:
      #   logs_saved_to_database — master switch for audit-log persistence
      #                          (maps to the "logs_enabled" key)
      #   use_test_email         — when true, every saved audit log triggers
      #                          an email notification to test_email
      #   test_email             — recipient address for test-mode notifications
      class ConfigurationsController < ApplicationController
        before_action :authorize_admin!

        # GET /api/v1/admin/configuration
        def show
          render json: configuration_json
        end

        # PATCH /api/v1/admin/configuration
        # Accepts { logs_saved_to_database:, test:, use_test_email:, test_email: }
        # and persists whichever are present (missing keys leave existing values
        # untouched). The SPA sends "use_test_email"; tests send "test". Both map
        # to the "test" app_setting key.
        def update
          settings = configuration_params
          AppSetting.set!(:logs_enabled, settings[:logs_saved_to_database]) if settings.key?(:logs_saved_to_database)
          if settings.key?(:test) || settings.key?(:use_test_email)
            AppSetting.set!(:test, settings[:test].presence || settings[:use_test_email].presence)
          end
          AppSetting.set!(:test_email, settings[:test_email]) if settings.key?(:test_email)
          AppSetting.set!(:bank_name, settings[:bank_name]) if settings.key?(:bank_name)
          AppSetting.set!(:bank_account_name, settings[:bank_account_name]) if settings.key?(:bank_account_name)
          AppSetting.set!(:bank_bsb, settings[:bank_bsb]) if settings.key?(:bank_bsb)
          AppSetting.set!(:bank_account, settings[:bank_account]) if settings.key?(:bank_account)

          render json: configuration_json
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.record.errors.full_messages.join(", ") },
                 status: :unprocessable_entity
        end

        private

        # Boolean-strong param: ActiveModel's boolean cast handles "true"/"false"/
        # 0/1 so JSON and form-encoded clients both work. Accepts both "test"
        # (used by tests) and "use_test_email" (sent by the React SPA).
        def configuration_params
          params.permit(:logs_saved_to_database, :test, :use_test_email, :test_email,
                        :bank_name, :bank_account_name, :bank_bsb, :bank_account)
        end

        def configuration_json
          {
            logs_saved_to_database: AppSetting.logs_enabled?,
            use_test_email: AppSetting.use_test_email?,
            test_email: AppSetting.test_email,
            bank_name: AppSetting.bank_name,
            bank_account_name: AppSetting.bank_account_name,
            bank_bsb: AppSetting.bank_bsb,
            bank_account: AppSetting.bank_account
          }
        end
      end
    end
  end
end
