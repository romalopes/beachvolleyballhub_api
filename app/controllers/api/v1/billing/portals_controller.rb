module Api
  module V1
    module Billing
      # POST /api/v1/billing/portal (IDENTITY-116, Phase 4).
      #
      # Opens Stripe's Customer Portal for the owner's own Customer. Payment method
      # changes and invoice downloads happen there, so card data never reaches this
      # application.
      class PortalsController < BaseController
        def create
          session = ::Billing::PortalService.new(user: Current.user, **owner_scope).call
          render json: { portal_url: session[:url] }
        end
      end
    end
  end
end
