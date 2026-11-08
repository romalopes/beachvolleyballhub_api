require "test_helper"

class Api::V1::WeatherControllerTest < ActionDispatch::IntegrationTest
  test "returns the normalized weather contract" do
    payload = {
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
      volleyball: {
        score: 78,
        label: "Good",
        advice: [ "UV is elevated: use sun protection." ],
        warnings: [],
        safety_override: false
      },
      attribution: { name: "WeatherAPI.com", url: "https://www.weatherapi.com/" }
    }

    with_weather_response(payload) do
      get "/api/v1/weather", params: { lat: -33.9, lon: 151.2 }
    end

    assert_response :success
    body = JSON.parse(response.body)
    expected = JSON.parse(payload.to_json)
    expected["volleyball"] = JSON.parse(
      Weather::VolleyballAdvisor.assess(
        current: payload[:current],
        rain_chance_percent: payload[:forecast].first[:rain_chance_percent]
      ).to_json
    )
    assert_equal expected, body
    assert_equal 78, payload.dig(:volleyball, :score), "the shared provider payload must not be mutated"
  end

  test "uses the signed-in account weights without changing independent warnings" do
    payload = {
      forecast: [ { rain_chance_percent: 10 } ],
      hourly: [],
      current: {
        wind_kph: 45.0,
        wind_gust_kph: 50.0,
        temperature_c: 24.0,
        feels_like_c: 24.0,
        humidity_percent: 50,
        uv_index: 2.0,
        precipitation_mm: 0.0
      },
      location: { latitude: 0, longitude: 0, timezone: "UTC" },
      updated_at: "2026-11-02T00:00:00Z",
      stale: false,
      volleyball: nil,
      attribution: { name: "WeatherAPI.com", url: "https://www.weatherapi.com/" }
    }
    accounts(:one).create_weather_advisor_preference!(
      wind_weight: 0,
      temperature_weight: 25,
      rain_weight: 25,
      uv_weight: 25,
      humidity_weight: 25
    )
    sign_in_as(users(:five))

    with_weather_response(payload) do
      get "/api/v1/weather", params: { lat: 0, lon: 0 }
    end

    assert_response :success
    assessment = JSON.parse(response.body).fetch("volleyball")
    assert_equal 100, assessment.fetch("score")
    assert_includes assessment.fetch("warnings"), "Dangerous gusts: postpone play and secure equipment."
    assert assessment.fetch("safety_override")
  end

  test "guest weather continues to use default weights" do
    payload = {
      forecast: [ { rain_chance_percent: 10 } ],
      hourly: [],
      current: { wind_kph: 45.0, temperature_c: 24.0 },
      location: { latitude: 0, longitude: 0, timezone: "UTC" },
      updated_at: "2026-11-02T00:00:00Z",
      stale: false,
      volleyball: nil,
      attribution: { name: "WeatherAPI.com", url: "https://www.weatherapi.com/" }
    }

    with_weather_response(payload) do
      get "/api/v1/weather", params: { lat: 0, lon: 0 }
    end

    assert_response :success
    assert_equal 60, JSON.parse(response.body).dig("volleyball", "score")
  end

  test "rejects missing or out-of-range coordinates" do
    get "/api/v1/weather", params: { lat: "invalid", lon: 181 }

    assert_response :unprocessable_entity
    assert_match(/lat must be a number/, JSON.parse(response.body)["error"])
  end

  test "returns service unavailable when the key is not configured" do
    with_weather_error(WeatherApi::ConfigurationError, "WEATHERAPI_API_KEY is not configured") do
      get "/api/v1/weather", params: { lat: 0, lon: 0 }
    end

    assert_response :service_unavailable
    assert_equal "WEATHERAPI_API_KEY is not configured", JSON.parse(response.body)["error"]
  end

  private

  def with_weather_response(payload)
    replace_weather_fetch(->(_latitude, _longitude) { payload }) { yield }
  end

  def with_weather_error(error_class, message)
    replacement = ->(_latitude, _longitude) { raise error_class, message }
    replace_weather_fetch(replacement) { yield }
  end

  def replace_weather_fetch(replacement)
    original = WeatherApi.method(:fetch_forecast)
    WeatherApi.define_singleton_method(:fetch_forecast, &replacement)
    yield
  ensure
    WeatherApi.define_singleton_method(:fetch_forecast, original)
  end
end
