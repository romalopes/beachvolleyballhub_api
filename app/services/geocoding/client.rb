# frozen_string_literal: true

require "digest"
require_relative "configuration_error"
require_relative "result"

module Geocoding
  class Client
    CACHE_VERSION = 1

    class << self
      def enabled?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("GEOCODING_ENABLED", "false"))
      end

      def configured?
        return false unless enabled?

        provider_name == "geoapify" && ENV["GEOAPIFY_API_KEY"].present?
      end

      def provider_name
        ENV.fetch("GEOCODING_PROVIDER", "geoapify").downcase
      end
    end

    def initialize(provider: nil, cache: Rails.cache)
      @provider = provider || build_provider
      @cache = cache
    end

    def search(query)
      normalized_query = query.to_s.squish
      raise ArgumentError, "Geocoding query cannot be blank" if normalized_query.blank?

      cache_key = "geocoding/v#{CACHE_VERSION}/#{self.class.provider_name}/#{Digest::SHA256.hexdigest(normalized_query.downcase)}"
      cached = @cache.read(cache_key)
      return deserialize(cached) if cached

      result = @provider.search(normalized_query)
      if result
        @cache.write(cache_key, result.to_h, expires_in: 30.days)
      else
        @cache.write(cache_key, { no_result: true }, expires_in: 1.day)
      end
      result
    end

    def reverse(latitude, longitude)
      return nil if latitude.blank? || longitude.blank?

      cache_key = "geocoding/reverse/v#{CACHE_VERSION}/#{self.class.provider_name}/#{Digest::SHA256.hexdigest("#{latitude},#{longitude}")}"
      cached = @cache.read(cache_key)
      return deserialize(cached) if cached

      result = @provider.reverse(latitude, longitude)
      if result
        @cache.write(cache_key, result.to_h, expires_in: 30.days)
      else
        @cache.write(cache_key, { no_result: true }, expires_in: 1.day)
      end
      result
    end

    private

    def build_provider
      case self.class.provider_name
      when "geoapify"
        Providers::Geoapify.new
      else
        raise ConfigurationError, "Unsupported geocoding provider: #{self.class.provider_name}"
      end
    end

    def deserialize(value)
      return nil if value[:no_result] || value["no_result"]

      attributes = value.symbolize_keys
      Result.new(**attributes.slice(*Result.members))
    end
  end
end
