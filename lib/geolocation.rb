# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# Resolves an IP address to a coarse location using the ip2location.io API.
#
# Lookup only happens when IP2LOCATION_API_KEY is configured. The free tier
# returns country / region / city. Any failure (missing key, network error,
# timeout, bad payload) returns nil — a missing location must never block or
# slow down authentication.
#
# Usage:
#   Geolocation.resolve("203.0.113.10")
#   # => { city: "Mountain View", region: "California", country: "United States of America" }
#   # or nil when not configured / on error
class Geolocation
  UNKNOWN = LoginDetails::UNKNOWN

  API_HOST = "api.ip2location.io"
  API_PATH = "/v2/?ip="
  TIMEOUT = 3 # seconds

  def self.resolve(ip)
    return nil if ip.nil? || ip == LoginDetails::UNKNOWN
    return nil unless api_key.present?

    new(ip).resolve
  rescue StandardError => e
    Rails.logger.warn("[geolocation] lookup failed for #{ip}: #{e.class}")
    nil
  end

  def initialize(ip)
    @ip = ip
  end

  def resolve
    uri = URI("https://#{API_HOST}#{API_PATH}#{@ip}&key=#{api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    response = http.get(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    return nil unless payload.is_a?(Hash) && payload["country_name"].present?

    {
      city: payload["city"],
      region: payload["region_name"],
      country: payload["country_name"]
    }
  rescue StandardError => e
    Rails.logger.warn("[geolocation] lookup failed for #{@ip}: #{e.class}")
    nil
  end

  private

  def api_key
    self.class.send(:api_key)
  end

  class << self
    private

    def api_key
      ENV["IP2LOCATION_API_KEY"].to_s.strip
    end
  end
end
