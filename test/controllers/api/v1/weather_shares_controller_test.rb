require "test_helper"

class Api::V1::WeatherSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:five)
    @other_user = users(:six)
  end

  test "create requires authentication" do
    post "/api/v1/weather_shares", params: {
      lat: -33.8688,
      lon: 151.2093,
      location_name: "Bondi Beach"
    }, as: :json

    assert_response :unauthorized
  end
test "create validates required parameters" do
    sign_in_as(@owner)

    post "/api/v1/weather_shares", params: {
      lat: "invalid",
      lon: 151.2093,
      location_name: "Bondi Beach"
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "lat must be a number"
  end

  test "create validates latitude range" do
    sign_in_as(@owner)

    post "/api/v1/weather_shares", params: {
      lat: 95,
      lon: 151.2093,
      location_name: "Bondi Beach"
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "lat must be a number between -90 and 90"
  end

  test "create validates longitude range" do
    sign_in_as(@owner)

    post "/api/v1/weather_shares", params: {
      lat: -33.8688,
      lon: 200,
      location_name: "Bondi Beach"
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "lon must be a number between -180 and 180"
  end

  test "create validates location_name presence" do
    sign_in_as(@owner)

    post "/api/v1/weather_shares", params: {
      lat: -33.8688,
      lon: 151.2093,
      location_name: ""
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal "location_name is required", JSON.parse(response.body)["error"]
  end
test "create accepts optional forecast_target_time" do
    sign_in_as(@owner)
    target_time = 1.day.from_now.iso8601

    with_weather_response do
      post "/api/v1/weather_shares", params: {
        lat: -33.8688,
        lon: 151.2093,
        location_name: "Bondi Beach",
        forecast_target_time: target_time
      }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["public_token"].present?
    assert body["public_url"].present?
    assert body["expires_at"].present?
  end

  test "create rejects invalid forecast_target_time" do
    sign_in_as(@owner)

    with_weather_response do
      post "/api/v1/weather_shares", params: {
        lat: -33.8688,
        lon: 151.2093,
        location_name: "Bondi Beach",
        forecast_target_time: "not-a-date"
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "forecast_target_time must be a valid ISO8601 timestamp"
  end

  test "destroy requires authentication" do
    snapshot = @owner.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [], hourly: [] }
    )

    delete "/api/v1/weather_shares/#{snapshot.public_token}", as: :json

    assert_response :forbidden
  end

  test "destroy revokes the snapshot" do
    sign_in_as(@owner)
    snapshot = @owner.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [], hourly: [] }
    )

    delete "/api/v1/weather_shares/#{snapshot.public_token}", as: :json

    assert_response :no_content
    assert snapshot.reload.revoked?
  end

  test "destroy forbids access to other account's snapshot" do
    sign_in_as(@owner)
    other_snapshot = @other_user.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Manly Beach",
      weather_data: { current: {}, forecast: [], hourly: [] }
    )

    delete "/api/v1/weather_shares/#{other_snapshot.public_token}", as: :json

    assert_response :forbidden
    assert_not other_snapshot.reload.revoked?
  end
test "metadata returns public data for valid token" do
    snapshot = @owner.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: { temperature_c: 25 }, forecast: [], hourly: [] },
      volleyball_score: 85,
      volleyball_label: "Excellent",
      volleyball_warnings: ["High UV"],
      volleyball_advice: ["Use sunscreen"],
      volleyball_safety_override: false
    )

    get "/api/v1/weather_shares/#{snapshot.public_token}/metadata", as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal snapshot.public_token, body["public_token"]
    assert_equal "Bondi Beach", body["location_name"]
    assert_equal 85, body["volleyball"]["score"]
    assert_equal "Excellent", body["volleyball"]["label"]
    assert_equal ["High UV"], body["volleyball"]["warnings"]
    assert_equal ["Use sunscreen"], body["volleyball"]["advice"]
    assert_equal false, body["volleyball"]["safety_override"]
    assert body["image_url"].nil?
    assert body["canonical_url"].present?
  end

  test "metadata returns 404 for expired token" do
    snapshot = @owner.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [], hourly: [] },
      expires_at: 1.day.ago
    )

    get "/api/v1/weather_shares/#{snapshot.public_token}/metadata", as: :json

    assert_response :not_found
    assert_equal "Share not found or has expired", JSON.parse(response.body)["error"]
  end

  test "metadata returns 404 for revoked token" do
    snapshot = @owner.account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [], hourly: [] }
    )
    snapshot.revoke!

    get "/api/v1/weather_shares/#{snapshot.public_token}/metadata", as: :json

    assert_response :not_found
  end

  test "metadata returns 404 for invalid token" do
    get "/api/v1/weather_shares/invalid-token/metadata", as: :json

    assert_response :not_found
  end

  private

  def with_weather_response(payload = default_weather_payload)
    replacement = ->(_latitude, _longitude) { payload }
    original = WeatherApi.method(:fetch_forecast)
    WeatherApi.define_singleton_method(:fetch_forecast, &replacement)
    yield
  ensure
    WeatherApi.define_singleton_method(:fetch_forecast, original)
  end

  def default_weather_payload
    {
      forecast: [
        {
          date: "2026-10-27",
          max_temp_c: 26,
          min_temp_c: 16,
          average_temp_c: 21,
          condition: "Sunny",
          icon_url: "https://cdn.weatherapi.com/icon.png",
          rain_chance_percent: 20,
          max_wind_kph: 24.0,
          max_wind_direction: "NE"
        }
      ],
      hourly: [
        {
          time: "2026-10-27 18:00",
          time_epoch: 1_793_107_200,
          temperature_c: 22.0,
          feels_like_c: 23.0,
          condition: "Partly cloudy",
          icon_url: "https://cdn.weatherapi.com/hour.png",
          rain_chance_percent: 20,
          wind_kph: 18.0,
          wind_gust_kph: 27.0,
          wind_direction: "NE"
        }
      ],
      current: {
        temperature_c: 23.0,
        feels_like_c: 24.0,
        condition: "Partly cloudy",
        condition_code: 1003,
        wind_kph: 18.0,
        wind_gust_kph: 27.0,
        wind_degree: 45,
        wind_direction: "NE",
        humidity_percent: 64,
        uv_index: 6.0,
        precipitation_mm: 0.0,
        icon_url: "https://cdn.weatherapi.com/current.png"
      },
      location: { latitude: -33.9, longitude: 151.2, timezone: "Australia/Sydney" },
      updated_at: "2026-10-27T05:00:00Z",
      stale: false,
      volleyball: nil,
      attribution: { name: "WeatherAPI.com", url: "https://www.weatherapi.com/" }
    }
  end
end