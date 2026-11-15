require "test_helper"

# Admin plan/feature management (IDENTITY-116). Admin-only, and destructive only
# when nothing references the plan.
class Api::V1::Admin::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)     # admin role
    @coach = users(:three)   # not an admin
    @admin_headers = sign_in_with_api_token(@admin).last
    @coach_headers = sign_in_with_api_token(@coach).last
  end

  test "non-admins cannot manage the catalogue" do
    get "/api/v1/admin/subscriptions", headers: @coach_headers
    assert_response :forbidden

    post "/api/v1/admin/subscriptions",
         params: { subscription: { name: "Sneaky", slug: "sneaky" } }.to_json,
         headers: @coach_headers
    assert_response :forbidden
  end

  test "admins see every plan, including inactive ones" do
    get "/api/v1/admin/subscriptions", headers: @admin_headers

    assert_response :success
    slugs = json_body["data"].map { |plan| plan["slug"] }
    assert_includes slugs, "legacy"
    assert_includes slugs, "free"
  end

  test "an admin can create a plan" do
    post "/api/v1/admin/subscriptions",
         params: { subscription: {
           name: "Academy", slug: "academy", currency: "AUD",
           yearly_price_cents: 2500, owner_scope: "organisation", position: 4
         } }.to_json,
         headers: @admin_headers

    assert_response :created
    assert_equal "academy", json_body.dig("subscription", "slug")
    assert_equal 2500, json_body.dig("subscription", "yearly_price_cents")
  end

  test "an invalid plan returns validation errors" do
    post "/api/v1/admin/subscriptions",
         params: { subscription: { name: "Bad", slug: "bad", yearly_price_cents: -5,
                                   currency: "AUD", owner_scope: "personal" } }.to_json,
         headers: @admin_headers

    assert_response :unprocessable_entity
    assert json_body["errors"].any?
  end

  test "updating display flags is allowed" do
    patch "/api/v1/admin/subscriptions/#{subscriptions(:player).id}",
          params: { subscription: { popular: false, position: 5 } }.to_json,
          headers: @admin_headers

    assert_response :success
    refute subscriptions(:player).reload.popular?
    assert_equal 5, subscriptions(:player).position
  end

  test "a plan with billing history is deactivated rather than deleted" do
    create_billing_subscription!(owner: accounts(:one), plan: subscriptions(:player))

    delete "/api/v1/admin/subscriptions/#{subscriptions(:player).id}", headers: @admin_headers

    assert_response :success
    assert json_body["deactivated"]
    plan = subscriptions(:player).reload
    refute plan.active?
    refute plan.visible?
  end

  test "an unreferenced plan is deleted" do
    plan = Subscription.create!(name: "Temporary", slug: "temporary", currency: "AUD",
                                yearly_price_cents: 100, owner_scope: "personal", position: 8)

    delete "/api/v1/admin/subscriptions/#{plan.id}", headers: @admin_headers

    assert_response :no_content
    assert_nil Subscription.find_by(id: plan.id)
  end

  test "plan features are replaced in the requested order" do
    put "/api/v1/admin/subscriptions/#{subscriptions(:player).id}/features",
        params: { feature_ids: [ subscription_features(:advanced_assessments).id,
                                 subscription_features(:enhanced_player_profile).id ] }.to_json,
        headers: @admin_headers

    assert_response :success
    slugs = subscriptions(:player).reload.feature_slugs
    assert_equal %w[advanced_assessments enhanced_player_profile], slugs
  end

  test "a feature attached to a plan is deactivated rather than deleted" do
    delete "/api/v1/admin/subscription_features/#{subscription_features(:enhanced_player_profile).id}",
           headers: @admin_headers

    assert_response :success
    assert json_body["deactivated"]
    refute subscription_features(:enhanced_player_profile).reload.active?
  end

  test "diagnostics report configuration presence without secrets" do
    get "/api/v1/admin/billing/diagnostics", headers: @admin_headers

    assert_response :success
    diagnostics = json_body["billing"]
    assert_includes diagnostics.keys, "secret_key_configured"
    refute_includes response.body, "sk_test"
  end
end
