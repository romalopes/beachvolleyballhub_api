# Server-side Cloudflare Turnstile verification for the public contact form
# (IDENTITY-259).
#
# The widget's client-side "success" callback is never trusted: the SPA forwards
# the token it received, and this service verifies it against Cloudflare's
# Siteverify endpoint using the secret key, which exists only in the API
# environment (`TURNSTILE_SECRET_KEY`) and never in the browser bundle.
#
# Failure policy (plan §6.1 — fail closed):
#   * key configured + accepted token              -> :valid
#   * key configured + rejected/missing/expired    -> :invalid
#   * key configured + provider or network error   -> :unavailable
#   * no key, development/test                     -> :disabled (local only)
#   * no key, production                           -> :unavailable (fail closed)
#
# `http_class` is injectable, matching WeatherApi/GeocodingProviders, so the
# request/response contract is unit-testable without network access.
class TurnstileVerifier
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  # The SPA renders the widget with this action; Cloudflare echoes it back so a
  # token minted for a different form cannot be replayed here.
  EXPECTED_ACTION = "contact"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 5

  Result = Data.define(:status, :errors) do
    # `:disabled` only happens outside production when no key is configured, so
    # local development and the test suite keep working without keys.
    def valid? = status == :valid || status == :disabled
    def invalid? = status == :invalid
    def unavailable? = status == :unavailable
  end

  def self.verify(token:, remote_ip: nil, secret: ENV["TURNSTILE_SECRET_KEY"],
                  expected_hostname: ENV["TURNSTILE_EXPECTED_HOSTNAME"].presence,
                  expected_action: EXPECTED_ACTION,
                  http_class: Net::HTTP,
                  production: Rails.env.production?)
    new(token: token, remote_ip: remote_ip, secret: secret,
        expected_hostname: expected_hostname, expected_action: expected_action,
        http_class: http_class, production: production).call
  end

  def initialize(token:, remote_ip:, secret:, expected_hostname:, expected_action:, http_class:,
                 production:)
    @token = token.to_s.strip
    @remote_ip = remote_ip
    @secret = secret.to_s.strip
    @expected_hostname = normalize_list(expected_hostname)
    @expected_action = expected_action.to_s.strip
    @http_class = http_class
    @production = production
  end

  def call
    return fail_closed("TURNSTILE_SECRET_KEY is not configured") if secret.blank? && production?
    return Result.new(status: :disabled, errors: []) if secret.blank?
    return invalid("missing token") if token.blank?

    payload = siteverify
    return invalid(*Array(payload["error-codes"]).map(&:to_s)) unless payload["success"] == true
    return invalid("action mismatch") if action_mismatch?(payload)
    return invalid("hostname mismatch") if hostname_mismatch?(payload)

    Result.new(status: :valid, errors: [])
  rescue StandardError => e
    # Provider outages and timeouts must not be treated as success.
    Rails.logger.error("[contact] turnstile verification error: #{e.class}: #{e.message}")
    Result.new(status: :unavailable, errors: [ "verification unavailable" ])
  end

  private

  attr_reader :token, :remote_ip, :secret, :expected_hostname, :expected_action, :http_class

  def production? = @production

  def siteverify
    uri = URI(VERIFY_URL)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Accept"] = "application/json"

    form = { secret: secret, response: token }
    # Behind Render/Cloudflare the client IP comes from the trusted-proxy
    # resolution (see production.rb), never from a raw, client-supplied header.
    form[:remoteip] = remote_ip if remote_ip.present?
    request.body = URI.encode_www_form(form)

    response = http_class.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) { |http| http.request(request) }

    raise "siteverify returned HTTP #{response.code}" unless response.code.to_s.start_with?("2")

    JSON.parse(response.body.to_s)
  end

  # Cloudflare only echoes `action`/`hostname` when the widget was rendered with
  # them, so a missing value is not a failure — a *different* value is.
  def action_mismatch?(payload)
    return false if expected_action.blank?

    actual = payload["action"].to_s
    actual.present? && actual != expected_action
  end

  def hostname_mismatch?(payload)
    return false if expected_hostname.empty?

    actual = payload["hostname"].to_s
    return false if actual.blank?

    !expected_hostname.include?(actual)
  end

  def invalid(*errors)
    Result.new(status: :invalid, errors: errors.flatten.compact_blank)
  end

  def fail_closed(reason)
    Rails.logger.error("[contact] turnstile unavailable: #{reason}")
    Result.new(status: :unavailable, errors: [ "verification unavailable" ])
  end

  def normalize_list(value)
    Array(value).flat_map { |entry| entry.to_s.split(",") }
                .map(&:strip)
                .reject(&:blank?)
  end
end
