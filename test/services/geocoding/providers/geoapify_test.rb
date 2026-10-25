require "test_helper"

class Geocoding::Providers::GeoapifyTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body)

  class FakeHttp
    attr_reader :last_request

    def initialize(response: nil, error: nil)
      @response = response
      @error = error
    end

    def self.for(response: nil, error: nil)
      instance = new(response: response, error: error)
      klass = Class.new do
        define_singleton_method(:start) do |_host, _port, **options, &block|
          instance.instance_variable_set(:@options, options)
          block.call(instance)
        end
      end
      [ klass, instance ]
    end

    def request(request)
      @last_request = request
      raise @error if @error

      @response
    end

    def options
      @options
    end
  end

  test "returns a normalized first result and sends the required request contract" do
    http_class, transport = FakeHttp.for(response: Response.new("200", {
      results: [ {
        lat: -33.9205,
        lon: 151.2552,
        formatted: "Coogee Beach, NSW, Australia",
        city: "Sydney",
        state: "New South Wales",
        country_code: "au",
        place_id: "place-123"
      } ]
    }.to_json))
    provider = build_provider(http_class)

    result = provider.search("Coogee Beach, Sydney, AU")

    assert_equal(-33.9205, result.latitude)
    assert_equal 151.2552, result.longitude
    assert_equal "geoapify", result.provider
    assert_equal "place-123", result.provider_reference
    query = Rack::Utils.parse_query(transport.last_request.uri.query)
    assert_equal "Coogee Beach, Sydney, AU", query["text"]
    assert_equal "json", query["format"]
    assert_equal "1", query["limit"]
    assert_equal "secret", query["apiKey"]
    assert_equal "application/json", transport.last_request["Accept"]
    assert_equal "BVB tests", transport.last_request["User-Agent"]
    assert_equal 2.0, transport.options[:open_timeout]
    assert_equal 4.0, transport.options[:read_timeout]
  end

  test "returns nil when the provider has no result" do
    http_class, = FakeHttp.for(response: Response.new("200", { results: [] }.to_json))

    assert_nil build_provider(http_class).search("Unknown venue")
  end

  test "raises a provider error for malformed JSON" do
    http_class, = FakeHttp.for(response: Response.new("200", "not-json"))

    assert_raises(Geocoding::ProviderError) { build_provider(http_class).search("Coogee") }
  end

  test "raises a transient error for timeouts and retryable statuses" do
    timeout_class, = FakeHttp.for(error: Net::ReadTimeout.new)
    status_class, = FakeHttp.for(response: Response.new("503", "{}"))

    assert_raises(Geocoding::TransientError) { build_provider(timeout_class).search("Coogee") }
    assert_raises(Geocoding::TransientError) { build_provider(status_class).search("Coogee") }
  end

  private

  def build_provider(http_class)
    Geocoding::Providers::Geoapify.new(
      api_key: "secret",
      base_url: "https://geo.example/search",
      open_timeout: 2,
      read_timeout: 4,
      user_agent: "BVB tests",
      http_class: http_class
    )
  end
end
