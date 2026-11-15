require "test_helper"

# Entitlements are enforced at the API boundary, not in React (IDENTITY-116,
# Phase 8). Enforcement is opt-in per environment, so the first test pins the
# default: existing role-based behaviour is unchanged until a deployment enables
# billing enforcement.
class Api::V1::SubscriptionEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @previous_flag = ENV["BILLING_ENFORCEMENT_ENABLED"]
    @coach = users(:six) # coach role, personal account two
    @headers = sign_in_with_api_token(@coach).last
    @organisation = organisations(:sydney_club)
  end

  teardown do
    ENV["BILLING_ENFORCEMENT_ENABLED"] = @previous_flag
  end

  test "enforcement is off by default so existing behaviour is unchanged" do
    ENV["BILLING_ENFORCEMENT_ENABLED"] = nil

    post "/api/v1/training_templates", params: template_payload.to_json, headers: @headers

    refute_equal 403, response.status
  end

  test "a FREE coach cannot plan training through the API" do
    ENV["BILLING_ENFORCEMENT_ENABLED"] = "true"

    post "/api/v1/training_templates", params: template_payload.to_json, headers: @headers

    assert_response :forbidden
    assert_equal "subscription_feature_required", json_body["code"]
    assert_equal "advanced_training_planning", json_body["feature"]
    assert_equal "coach", json_body.dig("suggested_plan", "slug")
    assert_equal 0, TrainingTemplate.where(name: "Enforcement test template").count
  end

  test "a Coach plan unlocks advanced training planning" do
    create_billing_subscription!(owner: accounts(:two), plan: subscriptions(:coach))
    ENV["BILLING_ENFORCEMENT_ENABLED"] = "true"

    post "/api/v1/training_templates", params: template_payload.to_json, headers: @headers

    assert_response :created
  end

  test "site admins are not blocked by subscription enforcement" do
    ENV["BILLING_ENFORCEMENT_ENABLED"] = "true"
    admin_headers = sign_in_with_api_token(users(:two)).last

    post "/api/v1/training_templates", params: template_payload.to_json, headers: admin_headers

    refute_equal 403, response.status
  end

  test "club management needs the Club subscription, not a personal Coacher plan" do
    create_billing_subscription!(owner: accounts(:two), plan: subscriptions(:coach))
    ENV["BILLING_ENFORCEMENT_ENABLED"] = "true"

    patch "/api/v1/organisations/#{@organisation.id}",
          params: { organisation: { description: "Managed by the club" } }.to_json,
          headers: @headers

    assert_response :forbidden
    assert_equal "organisation_management", json_body["feature"]
  end

  test "a Club subscription unlocks organisation management" do
    create_billing_subscription!(owner: @organisation, plan: subscriptions(:club))
    ENV["BILLING_ENFORCEMENT_ENABLED"] = "true"

    patch "/api/v1/organisations/#{@organisation.id}",
          params: { organisation: { description: "Managed by the club" } }.to_json,
          headers: @headers

    assert_response :success
    assert_equal "Managed by the club", @organisation.reload.description
  end

  private

  def template_payload
    {
      training_template: {
        name: "Enforcement test template",
        organisation_id: @organisation.id,
        duration_minutes: 60,
        visibility: "shared",
        status: "active"
      }
    }
  end
end
