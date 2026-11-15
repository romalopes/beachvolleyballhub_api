require "test_helper"

# Billing API authorization and status contracts (IDENTITY-116, Phase 4).
class Api::V1::BillingControllerTest < ActionDispatch::IntegrationTest
  FakePrice = Struct.new(:currency, :recurring)
  FakeRecurring = Struct.new(:interval)
  FakeCustomer = Struct.new(:id)
  FakeSession = Struct.new(:id, :url, :status, :expires_at)

  setup do
    @previous_secret = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_billing_api"
    @account = accounts(:three)
  end

  teardown do
    ENV["STRIPE_SECRET_KEY"] = @previous_secret
  end

  test "billing status requires authentication" do
    get "/api/v1/billing/status", headers: json_headers
    assert_response :unauthorized
  end

  test "a personal owner without a paid plan sees the FREE fallback" do
    _session, headers = sign_in_with_api_token(users(:three))

    get "/api/v1/billing/status", headers: headers

    assert_response :success
    body = json_body
    assert_equal "Account", body.dig("owner", "type")
    assert_equal @account.id, body.dig("owner", "id")
    assert_equal "free", body.dig("plan", "slug")
    assert body["free_fallback"]
    refute body["entitled"]
    assert body["can_checkout"]
    assert_equal [], body["features"]
    assert_equal 0, body.dig("limits", "included_users", "value")
  end

  test "a paid personal owner sees the plan and its features" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:coach))
    _session, headers = sign_in_with_api_token(users(:three))

    get "/api/v1/billing/status", headers: headers

    assert_response :success
    body = json_body
    assert_equal "coach", body.dig("plan", "slug")
    assert body["entitled"]
    refute body["free_fallback"]
    assert_includes body["features"].map { |f| f["slug"] }, "advanced_training_planning"
    assert_equal "active", body.dig("subscription", "status")
  end

  test "an organisation member who does not manage billing cannot read or change it" do
    _session, headers = sign_in_with_api_token(users(:five))

    get "/api/v1/billing/status",
        params: { owner_type: "organisation", owner_id: organisations(:sydney_club).id },
        headers: headers
    assert_response :forbidden

    post "/api/v1/billing/checkout",
         params: { plan_slug: "club", owner_type: "organisation",
                   owner_id: organisations(:sydney_club).id }.to_json,
         headers: headers
    assert_response :forbidden
  end

  test "an organisation owner can read the club's billing status" do
    create_billing_subscription!(owner: organisations(:sydney_club), plan: subscriptions(:club))
    _session, headers = sign_in_with_api_token(users(:six))

    get "/api/v1/billing/status",
        params: { owner_type: "organisation", owner_id: organisations(:sydney_club).id },
        headers: headers

    assert_response :success
    body = json_body
    assert_equal "Organisation", body.dig("owner", "type")
    assert_equal "club", body.dig("plan", "slug")
    assert body["features"].any? { |f| f["slug"] == "club_reporting" }
  end

  test "checkout fails safely when Stripe is not configured" do
    ENV["STRIPE_SECRET_KEY"] = nil
    _session, headers = sign_in_with_api_token(users(:three))

    post "/api/v1/billing/checkout", params: { plan_slug: "player" }.to_json, headers: headers

    assert_response :service_unavailable
    assert_equal "billing_not_configured", json_body["code"]
  end

  test "checkout creates a Stripe session for the authenticated owner" do
    session = FakeSession.new("cs_api_test", "https://checkout.stripe.test/cs_api_test", "open",
                              1.hour.from_now.to_i)
    _session, headers = sign_in_with_api_token(users(:three))

    stub_singleton_method(Billing::StripeGateway, :retrieve_price,
                          FakePrice.new("aud", FakeRecurring.new("year"))) do
      stub_singleton_method(Billing::StripeGateway, :create_customer, FakeCustomer.new("cus_api_test")) do
        stub_singleton_method(Billing::StripeGateway, :create_checkout_session, session) do
          post "/api/v1/billing/checkout", params: { plan_slug: "player" }.to_json, headers: headers
        end
      end
    end

    assert_response :created
    assert_equal "https://checkout.stripe.test/cs_api_test", json_body["checkout_url"]
    assert_equal "cs_api_test", json_body["session_id"]
  end

  test "checkout refuses the Club plan for a personal owner" do
    _session, headers = sign_in_with_api_token(users(:three))

    post "/api/v1/billing/checkout", params: { plan_slug: "club" }.to_json, headers: headers

    assert_response :unprocessable_entity
    assert_equal "subscription_plan_incompatible", json_body["code"]
  end

  test "billing history is scoped to the owner" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:player))
    _session, headers = sign_in_with_api_token(users(:three))

    get "/api/v1/billing/history", headers: headers

    assert_response :success
    assert_equal "Account", json_body.dig("owner", "type")
    assert_kind_of Array, json_body["data"]
  end
end
