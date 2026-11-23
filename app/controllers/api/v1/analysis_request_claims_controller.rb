module Api
  module V1
    class AnalysisRequestClaimsController < ApplicationController
      allow_unauthenticated_access

      def new
        @request = AnalysisRequest.find_by_guest_access!(params[:token])
        render json: { guest_email: @request.guest_email, guest_name: @request.guest_name }
      end

      def create
        @request = AnalysisRequest.find_by_guest_access!(params[:token])

        user = User.create!(
          email_address: @request.guest_email,
          password: params[:password],
          password_confirmation: params[:password_confirmation],
          email_verified_at: nil
        )

        account = user.create_account!(
          first_name: @request.guest_name&.split&.first,
          last_name: @request.guest_name&.split&.last,
          email: @request.guest_email
        )

        EmailVerificationService.send_verification(user)

        @request.update!(account: account, guest_name: nil, guest_email: nil, guest_access_token: nil)

        render json: { message: "Account created. Please verify your email.", account_id: account.id }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end