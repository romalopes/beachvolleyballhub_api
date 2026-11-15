require "test_helper"

# The public pricing catalogue (IDENTITY-116, Phase 4/7). The SPA must be able to
# render prices and features without any hardcoded catalogue, and must never
# receive a Stripe Price ID.
class Api::V1::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "returns visible active plans in display order with their features" do
    get "/api/v1/subscriptions", headers: json_headers

    assert_response :success
    body = json_body
    assert_equal %w[free player coach club], body["data"].map { |plan| plan["slug"] }
    assert_equal "AUD", body["meta"]["currency"]

    free = body["data"].first
    assert_equal 0, free["yearly_price_cents"]
    assert_equal "Free", free["price_label"]
    assert free["default"]
    assert_equal [], free["features"]

    player = body["data"].second
    assert_equal 500, player["yearly_price_cents"]
    assert_equal "A$5.00/year", player["price_label"]
    assert_equal %w[enhanced_player_profile], player["features"].map { |f| f["slug"] }
    assert_equal 0, player["included_users"]
    assert_equal 0, player["history_limit"]

    coach = body["data"].third
    assert_equal 3, coach["features"].size
    club = body["data"].last
    assert_equal "organisation", club["owner_scope"]
    assert_equal 5, club["features"].size
  end

  test "never exposes Stripe Price IDs or retired plans" do
    get "/api/v1/subscriptions", headers: json_headers

    assert_response :success
    refute_includes response.body, "price_player_test"
    refute_includes response.body, "legacy"
  end
end
