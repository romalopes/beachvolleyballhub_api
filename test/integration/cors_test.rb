require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  PRODUCTION_ORIGIN = "https://beachvolleyballhub.com".freeze
  CLOUDFLARE_ORIGIN = "https://beachvolleyballhub.romalopes.workers.dev".freeze

  test "allows the production frontend origin without a wildcard" do
    get "/api/v1/health", headers: { "Origin" => PRODUCTION_ORIGIN }

    assert_response :success
    assert_equal PRODUCTION_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    refute_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "allows the configured Cloudflare frontend origin" do
    get "/api/v1/health", headers: { "Origin" => CLOUDFLARE_ORIGIN }

    assert_response :success
    assert_equal CLOUDFLARE_ORIGIN, response.headers["Access-Control-Allow-Origin"]
  end

  test "responds to a production frontend preflight request" do
    options "/api/v1/skills", headers: {
      "Origin" => PRODUCTION_ORIGIN,
      "Access-Control-Request-Method" => "GET",
      "Access-Control-Request-Headers" => "authorization, content-type"
    }

    assert_response :success
    assert_equal PRODUCTION_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "GET"
    assert_includes response.headers["Access-Control-Allow-Headers"].downcase, "authorization"
    assert_includes response.headers["Access-Control-Allow-Headers"].downcase, "content-type"
  end

  test "does not allow an unconfigured browser origin" do
    get "/api/v1/health", headers: { "Origin" => "https://untrusted.example" }

    assert_response :success
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end
end