# frozen_string_literal: true

require "json"
require "net/http"
require_relative "../configuration_error"
require_relative "../provider_error"
require_relative "../result"
require_relative "../transient_error"

module Geocoding
  module Providers
    class Geoapify
      DEFAULT_BASE_URL = "https://api.geoapify.com/v1/geocode/search"

      def initialize(
        api_key: ENV["GEOAPIFY_API_KEY"],
        base_url: ENV.fetch("GEOAPIFY_BASE_URL", DEFAULT_BASE_URL),
        open_timeout: ENV.fetch("GEOCODING_OPEN_TIMEOUT", 3).to_f,
        read_timeout: ENV.fetch("GEOCODING_READ_TIMEOUT", 5).to_f,
        user_agent: ENV.fetch("GEOCODING_USER_AGENT", "BeachVolleyballHub/1.0"),
        http_class: Net::HTTP
      )
        @api_key = api_key.to_s
        @base_url = base_url
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @user_agent = user_agent
        @http_class = http_class
      end

      def search(query)
        raise ConfigurationError, "GEOAPIFY_API_KEY is not configured" if @api_key.blank?

        uri = URI(@base_url)
        uri.query = URI.encode_www_form(
          text: query,
          format: "json",
          limit: 1,
          apiKey: @api_key
        )
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["User-Agent"] = @user_agent

        response = @http_class.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @open_timeout,
          read_timeout: @read_timeout
        ) { |http| http.request(request) }

        parse_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED => e
        raise TransientError, "Geoapify request failed: #{e.class}"
      end

      def reverse(latitude, longitude)
        raise ConfigurationError, "GEOAPIFY_API_KEY is not configured" if @api_key.blank?

        uri = URI("https://api.geoapify.com/v1/geocode/reverse")
        uri.query = URI.encode_www_form(
          lat: latitude,
          lon: longitude,
          format: "json",
          limit: 1,
          apiKey: @api_key
        )
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["User-Agent"] = @user_agent

        response = @http_class.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @open_timeout,
          read_timeout: @read_timeout
        ) { |http| http.request(request) }

        parse_reverse_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED => e
        raise TransientError, "Geoapify reverse geocode failed: #{e.class}"
      end

      private

      def parse_response(response)
        status = response.code.to_i
        raise TransientError, "Geoapify returned HTTP #{status}" if status == 429 || status >= 500
        raise ProviderError, "Geoapify returned HTTP #{status}" unless status.between?(200, 299)

        payload = JSON.parse(response.body)
        rows = payload["results"]
        raise ProviderError, "Geoapify returned a malformed response" unless rows.is_a?(Array)
        return nil if rows.empty?

        row = rows.first
        latitude = Float(row.fetch("lat"))
        longitude = Float(row.fetch("lon"))
        Result.new(
          latitude: latitude,
          longitude: longitude,
          formatted_address: row["formatted"],
          locality: row["city"] || row["town"] || row["village"] || row["suburb"],
          administrative_area: row["state"],
          country_code: row["country_code"]&.upcase,
          provider: "geoapify",
          provider_reference: row["place_id"]
        )
      rescue JSON::ParserError, KeyError, TypeError, ArgumentError
        raise ProviderError, "Geoapify returned a malformed response"
      end

      def parse_reverse_response(response)
        status = response.code.to_i
        raise TransientError, "Geoapify reverse returned HTTP #{status}" if status == 429 || status >= 500
        raise ProviderError, "Geoapify reverse returned HTTP #{status}" unless status.between?(200, 299)

        payload = JSON.parse(response.body)
        rows = payload["results"]
        raise ProviderError, "Geoapify reverse returned a malformed response" unless rows.is_a?(Array)
        return nil if rows.empty?

        row = rows.first
        latitude = Float(row.fetch("lat"))
        longitude = Float(row.fetch("lon"))
        Result.new(
          latitude: latitude,
          longitude: longitude,
          formatted_address: row["formatted"],
          locality: row["city"] || row["town"] || row["village"] || row["suburb"],
          administrative_area: row["state"],
          country_code: row["country_code"]&.upcase,
          provider: "geoapify",
          provider_reference: row["place_id"]
        )
      rescue JSON::ParserError, KeyError, TypeError, ArgumentError
        raise ProviderError, "Geoapify reverse returned a malformed response"
      end
    end
  end
end
