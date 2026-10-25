require "test_helper"

class Geocoding::ClientTest < ActiveSupport::TestCase
  class CountingProvider
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = 0
    end

    def search(_query)
      @calls += 1
      @result
    end
  end

  class RecordingCache
    attr_reader :writes

    def initialize
      @values = {}
      @writes = []
    end

    def read(key)
      @values[key]
    end

    def write(key, value, **options)
      @values[key] = value
      @writes << { key: key, value: value, options: options }
      true
    end
  end

  test "caches a successful result for thirty days" do
    result = Geocoding::Result.new(
      latitude: -33.9205,
      longitude: 151.2552,
      formatted_address: "Coogee Beach, NSW, Australia",
      locality: "Sydney",
      administrative_area: "New South Wales",
      country_code: "AU",
      provider: "geoapify",
      provider_reference: "place-123"
    )
    provider = CountingProvider.new(result)
    cache = RecordingCache.new
    client = Geocoding::Client.new(provider: provider, cache: cache)

    first = client.search("Coogee Beach, Sydney, AU")
    second = client.search("Coogee Beach, Sydney, AU")

    assert_equal result, first
    assert_equal result, second
    assert_equal 1, provider.calls
    assert_equal cache_key("Coogee Beach, Sydney, AU"), cache.writes.first[:key]
    assert_equal 30.days, cache.writes.first.dig(:options, :expires_in)
  end

  test "caches no result for one day" do
    provider = CountingProvider.new(nil)
    cache = RecordingCache.new
    client = Geocoding::Client.new(provider: provider, cache: cache)

    assert_nil client.search("Unknown venue")
    assert_nil client.search("Unknown venue")
    assert_equal 1, provider.calls
    assert_equal cache_key("Unknown venue"), cache.writes.first[:key]
    assert_equal 1.day, cache.writes.first.dig(:options, :expires_in)
  end

  private

  def cache_key(query)
    digest = Digest::SHA256.hexdigest(query.downcase)
    "geocoding/v1/#{Geocoding::Client.provider_name}/#{digest}"
  end
end
