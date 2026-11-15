module Api
  module V1
    module Webhooks
      # POST /api/v1/webhooks/stripe (IDENTITY-116, Phase 5).
      #
      # This is Stripe's server-to-server endpoint, so it:
      #   * skips user authentication and the private test-access gate (Stripe
      #     cannot present either);
      #   * verifies the Stripe signature against the raw request body before any
      #     processing — the signature *is* the authentication;
      #   * returns 5xx only for transient failures, so Stripe retries those but
      #     does not retry a permanent correlation mismatch that has been recorded.
      #
      # It must never be challenged by Turnstile/bot protection in Cloudflare and
      # must not be cached (documented in docs/subscriptions/production-deployment.md).
      class StripeController < ApplicationController
        allow_test_access only: :create
        skip_before_action :require_authentication, raise: false

        def create
          secret = ::Billing::Configuration.webhook_secret
          raise ::Billing::Errors::NotConfigured if secret.blank?

          payload = request.raw_post
          signature = request.headers["Stripe-Signature"]
          raise ::Billing::Errors::WebhookSignatureInvalid if signature.blank?

          event = ::Billing::StripeGateway.verify_webhook(payload, signature, secret)
          result = ::Billing::WebhookProcessor.new(event).call

          render json: { received: true, result: result.to_s }, status: :ok
        rescue Stripe::SignatureVerificationError
          render json: { error: "Invalid Stripe webhook signature",
                         code: "webhook_signature_invalid" }, status: :bad_request
        rescue ::Billing::Errors::TransientFailure, Stripe::StripeError => e
          ::Billing::AuditLogger.error_event("webhook.transient_failure", e)
          render json: { error: "Temporary failure" }, status: :internal_server_error
        rescue ::Billing::Errors::BillingError => e
          render json: { error: e.message, code: e.code }, status: e.status
        end
      end
    end
  end
end
