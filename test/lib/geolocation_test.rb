require "test_helper"

class GeolocationTest < ActiveSupport::TestCase
  setup do
    @original_api_key = ENV["IP2LOCATION_API_KEY"]
  end

  teardown do
    ENV["IP2LOCATION_API_KEY"] = @original_api_key
  end

  test "loads the HTTP standard library dependencies used by the provider" do
    assert defined?(URI)
    assert defined?(Net::HTTP)
    assert defined?(Net::HTTPSuccess)
  end

  test "does not perform a lookup without an API key" do
    ENV["IP2LOCATION_API_KEY"] = nil

    assert_nil Geolocation.resolve("203.0.113.10")
  end

  test "resolves a configured IP without a NameError" do
    ENV["IP2LOCATION_API_KEY"] = "test-key"
    response = Net::HTTPOK.new("1.1", "200", "OK")
    body = JSON.generate("city" => "Lisbon", "region_name" => "Lisbon", "country_name" => "Portugal")
    response.define_singleton_method(:body) { body }
    http = Object.new
    http.define_singleton_method(:use_ssl=) { |_| }
    http.define_singleton_method(:open_timeout=) { |_| }
    http.define_singleton_method(:read_timeout=) { |_| }
    http.define_singleton_method(:get) { |_| response }

    original_new = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) { |*| http }

    begin
      assert_equal(
        { city: "Lisbon", region: "Lisbon", country: "Portugal" },
        Geolocation.resolve("203.0.113.10")
      )
    ensure
      Net::HTTP.define_singleton_method(:new, original_new)
    end
  end
end
