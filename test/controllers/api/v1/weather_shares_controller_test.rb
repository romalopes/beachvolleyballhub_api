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

  test "create snapshots the selected forecast hour and its advisor" do
    sign_in_as(@owner)
    payload = default_weather_payload
    payload[:hourly] = [
      {
        time: "2026-10-27 21:00",
        time_epoch: 1_793_118_000,
        temperature_c: 30.0,
        feels_like_c: 34.0,
        condition: "Sunny",
        icon_url: "https://cdn.weatherapi.com/hour.png",
        rain_chance_percent: 90,
        wind_kph: 45.0,
        wind_gust_kph: 55.0,
        wind_direction: "NW",
        humidity_percent: 90,
        uv_index: 12.0,
        precipitation_mm: 2.0
      }
    ]

    with_weather_response(payload) do
      post "/api/v1/weather_shares", params: {
        lat: -33.8688,
        lon: 151.2093,
        location_name: "Bondi Beach",
        forecast_target_time: Time.zone.at(1_793_118_000).iso8601
      }, as: :json
    end

    assert_response :created
    snapshot = WeatherShareSnapshot.find_by!(
      public_token: JSON.parse(response.body)["public_token"]
    )
    snapshotted_current = snapshot.weather_data["current"]

    assert_equal 1_793_118_000, snapshot.forecast_target_time.to_i
    assert_equal 1_793_118_000, snapshotted_current["time_epoch"]
    assert_equal 45.0, snapshotted_current["wind_kph"]
    assert_equal 12.0, snapshotted_current["uv_index"]
    assert_equal 90, snapshotted_current["rain_chance_percent"]

    expected = Weather::VolleyballAdvisor.assess(
      current: payload[:hourly].first,
      rain_chance_percent: payload[:hourly].first[:rain_chance_percent]
    )
    assert_equal expected[:score], snapshot.volleyball_score
    assert_equal expected[:label], snapshot.volleyball_label
    assert_includes snapshot.volleyball_warnings, "Dangerous gusts: postpone play and secure equipment."
    assert_includes snapshot.volleyball_warnings, "Extreme UV: limit time in direct sun."
  end

  test "create falls back to current conditions when the target hour is unavailable" do
    sign_in_as(@owner)

    with_weather_response do
      post "/api/v1/weather_shares", params: {
        lat: -33.8688,
        lon: 151.2093,
        location_name: "Bondi Beach",
        forecast_target_time: Time.zone.at(1_700_000_000).iso8601
      }, as: :json
    end

    assert_response :created
    snapshot = WeatherShareSnapshot.find_by!(
      public_token: JSON.parse(response.body)["public_token"]
    )

    assert_equal 23.0, snapshot.weather_data["current"]["temperature_c"]
    assert_nil snapshot.weather_data["current"]["time_epoch"]
    assert_empty snapshot.volleyball_warnings
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