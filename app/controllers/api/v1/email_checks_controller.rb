module Api
  module V1
    # Email registration probe for the hire-analysis flow (IDENTITY-265).
    #
    # Before a guest confirms their request, the SPA asks whether the email
    # already belongs to a registered account: if it does, the submitter is
    # offered the login form (so the request is linked to their account and
    # player profile); if it does not, they are offered account creation with
    # the usual benefits, or continuing as a guest.
    #
    # The response is intentionally limited to a boolean. This is by design an
    # account-existence oracle — the Wine Words trade-submission flow works the
    # same way — so it is rate limited hard and reveals nothing else about the
    # account.
    class EmailChecksController < ApplicationController
      allow_unauthenticated_access only: :show

      rate_limit to: 20, within: 1.minute, only: :show

      def show
        email = params[:email].to_s.strip.downcase
        return render json: { error: "Email is required." }, status: :bad_request if email.blank?

        registered = User.exists?(email_address: email)
        render json: { email_address: email, registered: registered }
      end
    end
  end
end
