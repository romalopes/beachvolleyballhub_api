require "test_helper"

class LocationGeocodingJobTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Coogee Beach",
      locality: "Sydney",
      country_code: "AU",
      geocoding_status: "pending"
    )
    @result = Geocoding::Result.new(
      latitude: -33.9205,
      longitude: 151.2552,
      formatted_address: "Coogee Beach, NSW, Australia",
      locality: "Sydney",
      administrative_area: "New South Wales",
      country_code: "AU",
      provider: "geoapify",
      provider_reference: "place-123"
    )
  end

  test "resolves coordinates and provenance" do
    client = Object.new
    client.define_singleton_method(:search) { |_query| @result }
    client.instance_variable_set(:@result, @result)

    with_geocoding_client(client) do
      LocationGeocodingJob.perform_now(@location.id, @location.geocoding_fingerprint)
    end

    @location.reload
    assert_equal "resolved", @location.geocoding_status
    assert_equal BigDecimal("-33.9205"), @location.latitude
    assert_equal "geoapify", @location.coordinate_source
    assert_equal "place-123", @location.source_reference
    assert_equal "Coogee Beach, NSW, Australia", @location.formatted_address
  end

  test "marks a no-result lookup failed" do
    client = Object.new
    client.define_singleton_method(:search) { |_query| nil }

    with_geocoding_client(client) do
      LocationGeocodingJob.perform_now(@location.id, @location.geocoding_fingerprint)
    end

    assert_equal "failed", @location.reload.geocoding_status
  end

  test "does not overwrite manual coordinates" do
    fingerprint = @location.geocoding_fingerprint
    @location.update!(
      latitude: -34,
      longitude: 151,
      geocoding_status: "manual",
      coordinate_source: "manual"
    )
    client = Object.new
    client.define_singleton_method(:search) { |_query| raise "client should not be called" }

    with_geocoding_client(client) do
      LocationGeocodingJob.perform_now(@location.id, fingerprint)
    end

    assert_equal BigDecimal("-34"), @location.reload.latitude
  end

  test "ignores a stale address fingerprint" do
    fingerprint = @location.geocoding_fingerprint
    @location.update!(name: "Maroubra Beach")
    client = Object.new
    client.define_singleton_method(:search) { |_query| raise "client should not be called" }

    with_geocoding_client(client) do
      LocationGeocodingJob.perform_now(@location.id, fingerprint)
    end

    assert_nil @location.reload.latitude
  end

  private

  def with_geocoding_client(client)
    singleton = Geocoding::Client.singleton_class
    original = singleton.instance_method(:new)
    singleton.define_method(:new) { |**_arguments| client }
    yield
  ensure
    singleton.define_method(:new, original)
  end
end
