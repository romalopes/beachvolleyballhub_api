# frozen_string_literal: true

require_relative "../services/geocoding/configuration_error"
require_relative "../services/geocoding/provider_error"
require_relative "../services/geocoding/transient_error"

class LocationGeocodingJob < ApplicationJob
  queue_as :background

  retry_on Geocoding::TransientError, wait: :polynomially_longer, attempts: 3 do |job, error|
    location = Location.find_by(id: job.arguments.first)
    fingerprint = job.arguments.second
    if location&.geocoding_job_applicable?(fingerprint)
      location.update_columns(geocoding_status: "failed", updated_at: Time.current)
    end
    Rails.logger.error("[geocoding] location #{job.arguments.first} failed after retries: #{error.message}")
  end

  def perform(location_id, expected_fingerprint)
    location = Location.find_by(id: location_id)
    return unless location&.geocoding_job_applicable?(expected_fingerprint)

    result = Geocoding::Client.new.search(location.geocoding_query)
    location.with_lock do
      return unless location.geocoding_job_applicable?(expected_fingerprint)

      if result
        location.update!(
          latitude: result.latitude,
          longitude: result.longitude,
          formatted_address: location.formatted_address.presence || result.formatted_address,
          locality: location.locality.presence || result.locality,
          administrative_area: location.administrative_area.presence || result.administrative_area,
          country_code: location.country_code.presence || result.country_code,
          geocoding_status: "resolved",
          coordinate_source: result.provider,
          source_reference: result.provider_reference
        )
      else
        location.update!(geocoding_status: "failed")
      end
    end
  rescue Geocoding::ConfigurationError, Geocoding::ProviderError => e
    if location&.geocoding_job_applicable?(expected_fingerprint)
      location.update_columns(geocoding_status: "failed", updated_at: Time.current)
    end
    Rails.logger.error("[geocoding] location #{location_id} failed: #{e.message}")
  end
end
