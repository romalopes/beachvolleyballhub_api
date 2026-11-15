require "test_helper"

# The webhook endpoint's own contract (IDENTITY-116, Phase 5): no session auth, no
# test-access gate, mandatory signature, retry semantics. Processing itself is
# covered by Billing::WebhookProcessorTest.
class Api::V1::WebhooksStripeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test_endpoint"
    @account = accounts(:three)
    @customer = create_billing_customer!(owner: @account)
  end

  teardown do
    ENV["STRIPE_WEBHOOK_SECRET"] = @previous_secret
  end

  test "a missing signature is rejected" do
    post "/api/v1/webhooks/stripe", params: {}.to_json, headers: json_headers

    assert_response :bad_request
    assert_equal "webhook_signature_invalid", json_body["code"]
  end

  test "an invalid signature is rejected without processing" do
    failing = ->(*_args) { raise Stripe::SignatureVerificationError.new("bad signature", nil) }

    stub_singleton_method(Billing::StripeGateway, :verify_webhook, failing) do
      post "/api/v1/webhooks/stripe", params: { id: "evt_bad" }.to_json,
           headers: json_headers.merge("Stripe-Signature" => "t=1,v1=bad")
    end

    assert_response :bad_request
    assert_equal 0, BillingEvent.count
  end

  test "a verified event is processed without a user session" do
    object = stripe_subscription_object(plan: subscriptions(:player),
                                        customer_id: @customer.stripe_customer_id)
    event = stripe_event(type: "customer.subscription.created", object: object)

    stub_singleton_method(Billing::StripeGateway, :verify_webhook, event) do
      post "/api/v1/webhooks/stripe", params: event.to_json,
           headers: json_headers.merge("Stripe-Signature" => "t=1,v1=signature")
    end

    assert_response :success
    assert_equal "processed", json_body["result"]
    assert_equal subscriptions(:player), @account.reload.billing_subscription.subscription
  end

  test "a transient Stripe failure returns 5xx so Stripe retries" do
    failing = ->(*_args) { raise Billing::Errors::TransientFailure, "Stripe is unavailable" }

    stub_singleton_method(Billing::StripeGateway, :verify_webhook, failing) do
      post "/api/v1/webhooks/stripe", params: { id: "evt_transient" }.to_json,
           headers: json_headers.merge("Stripe-Signature" => "t=1,v1=signature")
    end

    assert_response :internal_server_error
  end

  test "billing being unconfigured is a 503, not a silent success" do
    ENV["STRIPE_WEBHOOK_SECRET"] = nil

    post "/api/v1/webhooks/stripe", params: {}.to_json,
         headers: json_headers.merge("Stripe-Signature" => "t=1,v1=signature")

    assert_response :service_unavailable
    assert_equal "billing_not_configured", json_body["code"]
  end
end
