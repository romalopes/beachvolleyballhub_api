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
          max_wind_kph: 24.0
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
    assert_equal JSON.parse(payload.to_json), JSON.parse(response.body)
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