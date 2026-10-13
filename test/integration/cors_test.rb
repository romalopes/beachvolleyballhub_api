require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  ALLOWED_ORIGIN = "https://beachvolleyballhub.romalopes.workers.dev".freeze

  test "allows the configured Cloudflare frontend origin without a wildcard" do
    get "/api/v1/health", headers: { "Origin" => ALLOWED_ORIGIN }

    assert_response :success
    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    refute_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "does not allow an unconfigured browser origin" do
    get "/api/v1/health", headers: { "Origin" => "https://untrusted.example" }

    assert_response :success
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end
end