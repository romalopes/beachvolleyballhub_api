require "test_helper"

# Request tests for the notification preference endpoints. A missing row is
# materialised on demand, and the payload is always the caller's own.
class Api::V1::NotificationPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:five)  # account one
  end

  def json
    JSON.parse(response.body)
  end

  def patch_json(path, payload)
    patch path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  test "show requires authentication" do
    get "/api/v1/notification_preferences"
    assert_response :unauthorized
  end

  test "show materialises defaults for an account with no row" do
    sign_in_as(@owner)

    get "/api/v1/notification_preferences"

    assert_response :success
    assert_equal true, json["in_app_enabled"]
    assert_equal false, json["email_enabled"]
    assert_equal "immediate", json["email_cadence"]
  end

  test "update persists channel switches and mutes" do
    sign_in_as(@owner)

    patch_json "/api/v1/notification_preferences",
               notification_preference: {
                 in_app_enabled: true,
                 email_enabled: true,
                 email_cadence: "daily",
                 muted_event_types: [ "training.invited" ]
               }

    assert_response :success
    assert_equal "daily", json["email_cadence"]
    assert_equal [ "training.invited" ], json["muted_event_types"]

    preference = accounts(:one).reload.notification_preference
    assert preference.email_enabled?
    assert_equal "daily", preference.email_cadence
  end

  test "update rejects an unknown cadence" do
    sign_in_as(@owner)

    patch_json "/api/v1/notification_preferences",
               notification_preference: { email_cadence: "hourly" }

    assert_response :unprocessable_entity
    assert json["errors"].present?
  end
end
