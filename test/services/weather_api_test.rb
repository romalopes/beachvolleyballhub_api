require "test_helper"

class WeatherApiTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)

  test "normalizes a three-day forecast with current conditions and advisor" do
    response = FakeResponse.new("200", JSON.generate(
      location: { tz_id: "Australia/Sydney" },
      current: {
        temp_c: 21.5,
        feelslike_c: 22.0,
        condition: { text: "Partly cloudy", icon: "//cdn.weatherapi.com/current.png", code: 1003 },
        wind_kph: 18.0,
        gust_kph: 27.0,
        wind_degree: 45,
        wind_dir: "NE",
        humidity: 64,
        uv: 5.0,
        precip_mm: 0.0
      },
      forecast: {
        forecastday: (1..4).map do |day|
          {
            date: "2026-10-#{day + 26}",
            day: {
              maxtemp_c: 25 + day,
              mintemp_c: 15 + day,
              avgtemp_c: 20 + day,
              daily_chance_of_rain: 20,
              maxwind_kph: 24.0,
              condition: { text: "Sunny", icon: "//cdn.weatherapi.com/icon.png" }
            }
          }
        end
      }
    ))
    http = fake_http(response)

    result = WeatherApi.fetch_forecast(-33.9, 151.2, api_key: "secret", http_class: http)

    assert_equal 3, result[:forecast].length
    assert_equal "2026-10-27", result[:forecast].first[:date]
    assert_equal 26, result[:forecast].first[:max_temp_c]
    assert_equal 20, result[:forecast].first[:rain_chance_percent]
    assert_equal 24.0, result[:forecast].first[:max_wind_kph]
    assert_equal "https://cdn.weatherapi.com/icon.png", result[:forecast].first[:icon_url]
    assert_equal 21.5, result[:current][:temperature_c]
    assert_equal 27.0, result[:current][:wind_gust_kph]
    assert_equal "https://cdn.weatherapi.com/current.png", result[:current][:icon_url]
    assert_equal -33.9, result[:location][:latitude]
    assert_equal "Australia/Sydney", result[:location][:timezone]
    assert_equal false, result[:stale]
    assert_not_nil result[:updated_at]
    assert_equal 93, result[:volleyball][:score]
    assert_equal "Excellent", result[:volleyball][:label]
    assert_equal({ name: "WeatherAPI.com", url: "https://www.weatherapi.com/" }, result[:attribution])
  end

  test "requires an API key" do
    error = assert_raises(WeatherApi::ConfigurationError) do
      WeatherApi.fetch_forecast(0, 0, api_key: "")
    end

    assert_equal "WEATHERAPI_API_KEY is not configured", error.message
  end

  test "serves a cached forecast without hitting the provider again" do
    cache = ActiveSupport::Cache::MemoryStore.new
    response = FakeResponse.new("200", JSON.generate(
      forecast: {
        forecastday: [
          {
            date: "2026-10-27",
            day: {
              maxtemp_c: 26,
              mintemp_c: 16,
              avgtemp_c: 21,
              condition: { text: "Sunny", icon: "//cdn.weatherapi.com/icon.png" }
            }
          }
        ]
      }
    ))
    http = fake_http(response)

    first = WeatherApi.fetch_forecast(-33.9, 151.2, api_key: "secret", http_class: http, cache: cache)

    offline_http = Class.new do
      define_singleton_method(:start) { |*_args| raise "provider must not be called on cache hit" }
    end

    second = WeatherApi.fetch_forecast(-33.9, 151.2, api_key: "secret", http_class: offline_http, cache: cache)

    assert_equal first, second
  end

  test "maps unsuccessful provider responses" do
    http = fake_http(FakeResponse.new("429", "{}"))

    error = assert_raises(WeatherApi::ProviderError) do
      WeatherApi.fetch_forecast(0, 0, api_key: "secret", http_class: http)
    end

    assert_equal "provider returned HTTP 429", error.message
  end

  private

  def fake_http(response)
    Class.new do
      define_singleton_method(:start) do |*_args, **_kwargs, &block|
        client = Object.new
        client.define_singleton_method(:request) { |_request| response }
        block.call(client)
      end
    end
  end
end