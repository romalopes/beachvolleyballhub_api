require "test_helper"

# Cloudflare Turnstile verification (IDENTITY-259).
#
# The contract under test: a client-side success callback is never enough, a
# provider/network failure fails closed, and no key means "disabled" only outside
# production.
class TurnstileVerifierTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)

  SECRET = "test-secret".freeze

  def verify(**overrides)
    TurnstileVerifier.verify(**{
      token: "token",
      secret: SECRET,
      remote_ip: "203.0.113.10",
      http_class: fake_http(FakeResponse.new("200", JSON.generate(success: true)))
    }.merge(overrides))
  end

  test "a successful siteverify response is valid" do
    result = verify

    assert result.valid?
    assert_equal :valid, result.status
  end

  test "a rejected token is invalid and reports the provider error codes" do
    response = FakeResponse.new("200", JSON.generate(success: false, "error-codes": [ "invalid-input-response" ]))

    result = verify(http_class: fake_http(response))

    assert result.invalid?
    assert_includes result.errors, "invalid-input-response"
  end

  test "a missing token is rejected without calling the provider" do
    result = verify(token: "")

    assert result.invalid?
    assert_includes result.errors, "missing token"
  end

  test "an action mismatch is rejected" do
    response = FakeResponse.new("200", JSON.generate(success: true, action: "newsletter"))

    result = verify(http_class: fake_http(response))

    assert result.invalid?
    assert_includes result.errors, "action mismatch"
  end

  test "the expected action is accepted" do
    response = FakeResponse.new("200", JSON.generate(success: true, action: "contact"))

    assert verify(http_class: fake_http(response)).valid?
  end

  test "a hostname mismatch is rejected when expected hostnames are configured" do
    response = FakeResponse.new("200", JSON.generate(success: true, hostname: "evil.example"))

    result = verify(expected_hostname: "beachvolleyballhub.com", http_class: fake_http(response))

    assert result.invalid?
    assert_includes result.errors, "hostname mismatch"
  end

  test "a hostname in the configured list is accepted" do
    response = FakeResponse.new("200", JSON.generate(success: true, hostname: "www.beachvolleyballhub.com"))

    result = verify(expected_hostname: "beachvolleyballhub.com,www.beachvolleyballhub.com",
                    http_class: fake_http(response))

    assert result.valid?
  end

  test "a provider HTTP error fails closed" do
    result = verify(http_class: fake_http(FakeResponse.new("500", "{}")))

    assert result.unavailable?
    assert_not result.valid?
  end

  test "a network exception fails closed" do
    exploding = Class.new do
      def self.start(*_args, **_kwargs)
        raise IOError, "connection reset"
      end
    end

    result = verify(http_class: exploding)

    assert result.unavailable?
  end

  test "malformed provider JSON fails closed" do
    result = verify(http_class: fake_http(FakeResponse.new("200", "not json")))

    assert result.unavailable?
  end

  test "without a key, verification is disabled outside production" do
    result = verify(secret: nil, production: false)

    assert result.valid?
    assert_equal :disabled, result.status
  end

  test "without a key, production fails closed" do
    result = verify(secret: "", production: true)

    assert result.unavailable?
    assert_not result.valid?
  end

  test "the remote IP is forwarded to the provider when present" do
    request_body = nil
    http = Class.new do
      define_singleton_method(:start) do |*_args, **_kwargs, &block|
        client = Object.new
        client.define_singleton_method(:request) do |request|
          request_body = request.body
          FakeResponse.new("200", JSON.generate(success: true))
        end
        block.call(client)
      end
    end

    verify(http_class: http)

    assert_includes request_body, "remoteip=203.0.113.10"
    refute_includes request_body, "remoteip=203.0.113.10%0D"
  end

  def fake_http(response)
    Class.new do
      define_singleton_method(:start) do |*_args, **_kwargs, &block|
        client = Object.new
        client.define_singleton_method(:request) { |_request| response }
        block.call(client)
      end
    end
  end
end
