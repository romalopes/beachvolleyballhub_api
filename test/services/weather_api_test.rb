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
            },
            hour: forecast_hours(day)
          }
        end
      }
    ))
    http = fake_http(response)

    result = travel_to(Time.utc(2026, 10, 27, 5, 0, 0)) do
      WeatherApi.fetch_forecast(-33.9, 151.2, api_key: "secret", http_class: http)
    end

    assert_equal 3, result[:forecast].length
    assert_equal "2026-10-27", result[:forecast].first[:date]
    assert_equal 26, result[:forecast].first[:max_temp_c]
    assert_equal 20, result[:forecast].first[:rain_chance_percent]
    assert_equal 24.0, result[:forecast].first[:max_wind_kph]
    assert_equal "NW", result[:forecast].first[:max_wind_direction]
    assert_equal "https://cdn.weatherapi.com/icon.png", result[:forecast].first[:icon_url]
    assert_equal 8, result[:hourly].length
    assert_equal "2026-10-27 18:00", result[:hourly].first[:time]
    assert_equal "2026-10-28 15:00", result[:hourly].last[:time]
    assert_equal "https://cdn.weatherapi.com/hour.png", result[:hourly].first[:icon_url]
    assert_equal "NE", result[:hourly].first[:wind_direction]
    assert_equal 30.0, result[:hourly].first[:wind_gust_kph]
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

  test "filters past and non-boundary hours and continues across midnight" do
    response = FakeResponse.new("200", JSON.generate(
      forecast: {
        forecastday: [
          weather_day("2026-10-27", [
            weather_hour("2026-10-27 15:00", Time.utc(2026, 10, 27, 4).to_i),
            weather_hour("2026-10-27 17:00", Time.utc(2026, 10, 27, 6).to_i),
            weather_hour("2026-10-27 18:00", Time.utc(2026, 10, 27, 7).to_i)
          ]),
          weather_day("2026-10-28", [
            weather_hour("2026-10-28 00:00", Time.utc(2026, 10, 27, 13).to_i),
            weather_hour("2026-10-28 03:00", Time.utc(2026, 10, 27, 16).to_i)
          ])
        ]
      }
    ))

    result = travel_to(Time.utc(2026, 10, 27, 5)) do
      WeatherApi.fetch_forecast(0, 0, api_key: "secret", http_class: fake_http(response), cache: nil)
    end

    assert_equal [
      "2026-10-27 18:00",
      "2026-10-28 00:00",
      "2026-10-28 03:00"
    ], result[:hourly].pluck(:time)
  end

  test "normalizes missing hourly details and daily direction safely" do
    day = weather_day("2026-10-27", [
      {
        time: "2026-10-27 18:00",
        time_epoch: Time.utc(2026, 10, 27, 7).to_i,
        temp_c: nil,
        condition: nil,
        wind_kph: nil
      }
    ])
    response = FakeResponse.new("200", JSON.generate(forecast: { forecastday: [day] }))

    result = travel_to(Time.utc(2026, 10, 27, 5)) do
      WeatherApi.fetch_forecast(0, 0, api_key: "secret", http_class: fake_http(response), cache: nil)
    end

    assert_nil result[:forecast].first[:max_wind_direction]
    assert_nil result[:hourly].first[:condition]
    assert_equal "", result[:hourly].first[:icon_url]
    assert_nil result[:hourly].first[:wind_direction]
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

  def forecast_hours(day)
    date = Date.new(2026, 10, day + 26)
    (0..23).map do |hour|
      weather_hour(
        format("%s %02d:00", date, hour),
        (Time.utc(2026, 10, day + 26) + (hour - 11).hours).to_i,
        wind_kph: hour == 20 ? 40.0 : 18.0,
        wind_dir: hour == 20 ? "NW" : "NE"
      )
    end
  end

  def weather_day(date, hours)
    {
      date: date,
      day: {
        maxtemp_c: 26,
        mintemp_c: 16,
        avgtemp_c: 21,
        daily_chance_of_rain: 20,
        maxwind_kph: 40.0,
        condition: { text: "Sunny", icon: "//cdn.weatherapi.com/icon.png" }
      },
      hour: hours
    }
  end

  def weather_hour(time, epoch, wind_kph: 18.0, wind_dir: "NE")
    {
      time: time,
      time_epoch: epoch,
      temp_c: 22.0,
      feelslike_c: 23.0,
      chance_of_rain: 20,
      wind_kph: wind_kph,
      gust_kph: 30.0,
      wind_dir: wind_dir,
      condition: { text: "Partly cloudy", icon: "//cdn.weatherapi.com/hour.png" }
    }
  end

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