require "test_helper"

class ApiSmokeTest < ActionDispatch::IntegrationTest
  test "public health endpoint exposes the minimum liveness contract" do
    get "/api/v1/health", headers: json_headers

    assert_response :success
    assert_equal({ "status" => "ok", "version" => APP_VERSION }, json_body)
  end

  test "current-user endpoint requires authentication" do
    get "/api/v1/me", headers: json_headers

    assert_response :unauthorized
    assert_empty response.body
  end

  test "current-user endpoint returns the authenticated user's identity" do
    session, headers = sign_in_with_api_token(users(:one))

    get "/api/v1/me", headers: headers

    assert_response :success
    assert_equal users(:one).id, json_body["id"]
    assert_equal users(:one).email_address, json_body["email_address"]
    assert_includes json_body["roles"], "player"
  ensure
    session&.destroy!
  end

  test "session endpoint returns a bearer token for API clients" do
    post "/api/v1/sessions",
         params: { email_address: users(:one).email_address, password: "password", api: true }.to_json,
         headers: json_headers

    assert_response :success
    assert_equal users(:one).email_address, json_body["email_address"]
    assert json_body["token"].present?
    assert_nil json_body["password"]
  end

  test "protected health diagnostics distinguish unauthenticated callers" do
    get "/api/v1/health/detailed", headers: json_headers

    assert_response :unauthorized
    assert_empty response.body
  end
end
