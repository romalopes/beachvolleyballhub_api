require "json"
require "net/http"
require_relative "weather/volleyball_advisor"

class WeatherApi
  class ConfigurationError < StandardError; end
  class ProviderError < StandardError; end

  BASE_URL = "https://api.weatherapi.com/v1/forecast.json"
  FORECAST_DAYS = 3
  HOURLY_INTERVAL_HOURS = 3
  HOURLY_FORECAST_COUNT = 8
  ATTRIBUTION = { name: "WeatherAPI.com", url: "https://www.weatherapi.com/" }.freeze

  def self.fetch_forecast(latitude, longitude, api_key: ENV["WEATHERAPI_API_KEY"], http_class: Net::HTTP, cache: Rails.cache)
    raise ConfigurationError, "WEATHERAPI_API_KEY is not configured" if api_key.blank?

    cache_key = "weather/v3/#{latitude.round(2)},#{longitude.round(2)}/days-#{FORECAST_DAYS}"
    cached = cache&.read(cache_key)
    return cached if cached

    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(
      key: api_key,
      q: "#{latitude},#{longitude}",
      days: FORECAST_DAYS,
      aqi: "no",
      alerts: "no"
    )
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"
    request["User-Agent"] = "BeachVolleyballHub/1.0"
    response = http_class.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: 3,
      read_timeout: 5
    ) { |http| http.request(request) }

    status = response.code.to_i
    raise ProviderError, "provider returned HTTP #{status}" unless status.between?(200, 299)

    body = JSON.parse(response.body)
    days = body.dig("forecast", "forecastday")
    raise ProviderError, "provider returned a malformed response" unless days.is_a?(Array)

    current = normalize_current(body["current"])
    daily = days.first(FORECAST_DAYS).map { |day| normalize_day(day) }
    hourly = normalize_hourly(days, Time.now.to_i)

    forecast = {
      forecast: daily,
      hourly: hourly,
      current: current,
      location: normalize_location(body["location"], latitude, longitude),
      updated_at: Time.now.utc.iso8601,
      stale: false,
      volleyball: Weather::VolleyballAdvisor.assess(
        current: current,
        rain_chance_percent: daily.first&.dig(:rain_chance_percent)
      ),
      attribution: ATTRIBUTION
    }
    ttl = ENV.fetch("WEATHER_CACHE_TTL_SECONDS", 900).to_i
    cache&.write(cache_key, forecast, expires_in: ttl.seconds) if ttl.positive?

    forecast
  rescue JSON::ParserError, KeyError, TypeError, ArgumentError
    raise ProviderError, "provider returned a malformed response"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED => error
    raise ProviderError, "provider request failed: #{error.class}"
  end

  def self.normalize_day(day)
    details = day.fetch("day")
    condition = details.fetch("condition")
    icon_url = condition.fetch("icon").to_s
    icon_url = "https:#{icon_url}" if icon_url.start_with?("//")

    max_wind_hour = Array(day["hour"])
      .select { |hour| hour.is_a?(Hash) && hour["wind_kph"].is_a?(Numeric) }
      .max_by { |hour| hour["wind_kph"] }

    {
      date: day.fetch("date"),
      max_temp_c: details.fetch("maxtemp_c"),
      min_temp_c: details.fetch("mintemp_c"),
      average_temp_c: details.fetch("avgtemp_c"),
      condition: condition.fetch("text"),
      icon_url: icon_url,
      rain_chance_percent: details["daily_chance_of_rain"],
      max_wind_kph: details["maxwind_kph"],
      max_wind_direction: max_wind_hour&.dig("wind_dir")
    }
  end

  def self.normalize_hourly(days, current_epoch)
    days
      .flat_map { |day| Array(day["hour"]) }
      .select { |hour| eligible_hour?(hour, current_epoch) }
      .sort_by { |hour| hour["time_epoch"] }
      .first(HOURLY_FORECAST_COUNT)
      .map { |hour| normalize_hour(hour) }
  end

  def self.eligible_hour?(hour, current_epoch)
    return false unless hour.is_a?(Hash) && hour["time_epoch"].is_a?(Numeric)

    local_time = hour["time"].to_s
    local_hour = local_time[/\b(\d{2}):\d{2}\z/, 1]
    hour["time_epoch"] >= current_epoch && local_hour && (local_hour.to_i % HOURLY_INTERVAL_HOURS).zero?
  end

  def self.normalize_hour(hour)
    condition = hour["condition"].is_a?(Hash) ? hour["condition"] : {}

    {
      time: hour["time"],
      time_epoch: hour["time_epoch"],
      temperature_c: hour["temp_c"],
      feels_like_c: hour["feelslike_c"],
      condition: condition["text"],
      icon_url: normalize_icon_url(condition["icon"]),
      rain_chance_percent: hour["chance_of_rain"],
      wind_kph: hour["wind_kph"],
      wind_gust_kph: hour["gust_kph"],
      wind_direction: hour["wind_dir"]
    }
  end

  def self.normalize_current(current)
    return nil unless current.is_a?(Hash)

    condition = current["condition"].is_a?(Hash) ? current["condition"] : {}
    icon_url = normalize_icon_url(condition["icon"])

    {
      temperature_c: current["temp_c"],
      feels_like_c: current["feelslike_c"],
      condition: condition["text"],
      condition_code: condition["code"],
      wind_kph: current["wind_kph"],
      wind_gust_kph: current["gust_kph"],
      wind_degree: current["wind_degree"],
      wind_direction: current["wind_dir"],
      humidity_percent: current["humidity"],
      uv_index: current["uv"],
      precipitation_mm: current["precip_mm"],
      icon_url: icon_url
    }
  end

  def self.normalize_location(location, latitude, longitude)
    {
      latitude: latitude,
      longitude: longitude,
      timezone: location.is_a?(Hash) ? location["tz_id"] : nil
    }
  end

  def self.normalize_icon_url(icon)
    icon_url = icon.to_s
    icon_url.start_with?("//") ? "https:#{icon_url}" : icon_url
  end

  private_class_method :normalize_day, :normalize_hourly, :eligible_hour?, :normalize_hour,
    :normalize_current, :normalize_location, :normalize_icon_url
end