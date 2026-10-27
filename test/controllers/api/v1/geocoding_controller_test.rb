require "test_helper"

class Api::V1::GeocodingControllerTest < ActionDispatch::IntegrationTest
  def with_geocoding_replaced(behaviour)
    client = Geocoding::Client.new
    client.define_singleton_method(:search) { |_query| behaviour.call }
    original_new = Geocoding::Client.method(:new)
    Geocoding::Client.define_singleton_method(:new) { |*_args| client }
    yield
  ensure
    Geocoding::Client.define_singleton_method(:new, original_new)
  end

  def adelaide_result
    Geocoding::Result.new(
      latitude: -34.9287,
      longitude: 138.5986,
      formatted_address: "Adelaide SA, Australia",
      locality: "Adelaide",
      administrative_area: "South Australia",
      country_code: "AU",
      provider: "geoapify",
      provider_reference: "abc123"
    )
  end

  test "returns coordinates for a search query" do
    with_geocoding_replaced(-> { adelaide_result }) do
      get "/api/v1/geocode", params: { q: "adelaide, SA" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_in_delta -34.9287, body["latitude"]
    assert_in_delta 138.5986, body["longitude"]
    assert_equal "Adelaide SA, Australia", body["formatted_address"]
    assert_equal "AU", body["country_code"]
  end

  test "returns not found when the query has no match" do
    with_geocoding_replaced(-> { nil }) do
      get "/api/v1/geocode", params: { q: "middle of nowhere" }
    end

    assert_response :not_found
    assert_equal "No matching location was found", JSON.parse(response.body)["error"]
  end

  test "requires a query" do
    get "/api/v1/geocode"

    assert_response :unprocessable_entity
    assert_equal "q parameter is required", JSON.parse(response.body)["error"]
  end

  test "returns service unavailable when geocoding is not configured" do
    with_geocoding_replaced(
      -> { raise Geocoding::ConfigurationError, "GEOAPIFY_API_KEY is not configured" }
    ) do
      get "/api/v1/geocode", params: { q: "adelaide" }
    end

    assert_response :service_unavailable
    assert_equal "GEOAPIFY_API_KEY is not configured", JSON.parse(response.body)["error"]
  end
end