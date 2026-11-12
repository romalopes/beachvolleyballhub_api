require "test_helper"

class Public::WeatherSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:five)
    @snapshot = @owner.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: {
        current: { temperature_c: 25, condition: "Sunny", wind_kph: 15, humidity_percent: 60, uv_index: 5 },
        forecast: [],
        hourly: []
      },
      volleyball_score: 85,
      volleyball_label: "Excellent",
      volleyball_warnings: ["High UV"],
      volleyball_advice: ["Use sunscreen"],
      volleyball_safety_override: false
    )
  end

  test "show returns HTML with OG metadata for active snapshot" do
    get "/weather/#{@snapshot.public_token}"

    assert_response :success
    assert_equal "text/html", response.media_type

    # Check OG meta tags are present
    assert_includes response.body, 'property="og:title"'
    assert_includes response.body, 'property="og:description"'
    assert_includes response.body, 'property="og:image"'
    assert_includes response.body, 'property="og:url"'
    assert_includes response.body, 'property="og:type"'
    assert_includes response.body, 'property="og:site_name"'

    # Check Twitter Card tags
    assert_includes response.body, 'name="twitter:card"'
    assert_includes response.body, 'name="twitter:title"'
    assert_includes response.body, 'name="twitter:description"'
    assert_includes response.body, 'name="twitter:image"'

    # Check canonical URL
    assert_includes response.body, 'rel="canonical"'

    # Check content includes snapshot data
    assert_includes response.body, "Bondi Beach"
    assert_includes response.body, "Excellent"
    assert_includes response.body, "85/100"
  end

  test "show formats selected forecast time in the snapshot timezone" do
    @snapshot.update!(
      forecast_target_time: Time.iso8601("2026-11-12T08:00:00Z"),
      timezone: "Australia/Sydney"
    )

    get "/weather/#{@snapshot.public_token}"

    assert_response :success
    assert_includes response.body, "Forecast for Thu 12 Nov, 19:00"
  end

  test "show returns 404 for expired snapshot" do
    @snapshot.update!(expires_at: 1.day.ago)

    get "/weather/#{@snapshot.public_token}"

    assert_response :not_found
    assert_includes response.body, "Share Unavailable"
    assert_includes response.body, "expired"
  end

  test "show returns 404 for revoked snapshot" do
    @snapshot.revoke!

    get "/weather/#{@snapshot.public_token}"

    assert_response :not_found
    assert_includes response.body, "Share Unavailable"
    assert_includes response.body, "revoked"
  end

  test "show returns 404 for invalid token" do
    get "/weather/invalid-token"

    assert_response :not_found
    assert_includes response.body, "Share Unavailable"
  end

  test "show sets conservative cache headers" do
    get "/weather/#{@snapshot.public_token}"

    assert_response :success
    # Header order may vary, check for all components
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=300"
    assert_includes response.headers["Cache-Control"], "stale-while-revalidate=60"
    assert_includes response.headers["Vary"], "Accept"
  end

  test "show includes preload link for image" do
    @snapshot.update!(image_url: "https://example.com/image.png")

    get "/weather/#{@snapshot.public_token}"

    assert_includes response.body, 'rel="preload"'
    assert_includes response.body, 'as="image"'
    assert_includes response.body, 'https://example.com/image.png'
  end

  test "show works without authentication" do
    # No sign_in_as - should work as public endpoint
    get "/weather/#{@snapshot.public_token}"

    assert_response :success
  end
end
