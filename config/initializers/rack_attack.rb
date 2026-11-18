# Rack::Attack - Rate limiting configuration (Rack::Attack 6.x API)

# Throttle by IP address (new 6.x API: options hash as 2nd arg)
Rack::Attack.throttle('ip throttle', limit: 100, period: 1.minute) do |req|
  req.ip
end

# Throttle by authenticated user (if available)
Rack::Attack.throttle('user throttle', limit: 100, period: 1.minute) do |req|
  if req.env['warden'] && req.env['warden'].user
    req.env['warden'].user.id
  else
    req.ip
  end
end

# Custom throttled responder (Rack::Attack 6.x: throttled_responder instead of throttled_response)
Rack::Attack.throttled_responder = lambda do |env|
  retry_after = (Rack::Attack.last_request.env['rack.attack.throttled.retry_after'] || 1).to_s
  [
    429,
    {
      'Retry-After' => retry_after,
      'Content-Type' => 'application/json',
      'X-RateLimit-Limit' => '100',
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => retry_after
    },
    [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
  ]
end

# Safelist specific paths (e.g., health checks)
Rack::Attack.safelist('health check') do |req|
  req.path == '/health' || req.path == '/health/detailed'
end

# Stripe webhooks are server-to-server and signed. They must never be throttled
# or challenged: a rate-limited webhook means a payment that never activates.
# Signature verification, not rate limiting, is the protection here
# (IDENTITY-116, Phase 10).
Rack::Attack.safelist('stripe webhook') do |req|
  req.path == '/api/v1/webhooks/stripe'
end

# Billing session creation is expensive (Stripe API call) and user-initiated, so
# it gets a tighter limit than the general request throttle. Checkout, Portal and
# plan changes are the endpoints a script could hammer to create sessions.
BILLING_THROTTLED_PATHS = %w[
  /api/v1/billing/checkout
  /api/v1/billing/portal
  /api/v1/billing/change_subscription
].freeze

Rack::Attack.throttle('billing session creation', limit: 10, period: 1.minute) do |req|
  next unless req.post? && BILLING_THROTTLED_PATHS.include?(req.path)

  req.env['HTTP_AUTHORIZATION'].presence || req.ip
end

# Public contact form (IDENTITY-259).
#
# A layered defence, not a single gate: Rack::Attack bounds the volume, Cloudflare
# Turnstile proves the client is human, and the honeypot catches naive bots.
#
# Limits are deliberately low because the endpoint is anonymous, and configurable
# because a shared club/venue NAT is a legitimate client. `req.ip` is only the
# forwarded address when the trusted-proxy configuration resolves it — see
# config/environments/production.rb.
CONTACT_FORM_PATH = '/api/v1/contact_messages'

CONTACT_BURST_LIMIT = Integer(ENV.fetch('CONTACT_RATE_LIMIT_PER_10_MINUTES', '5'))
CONTACT_DAILY_LIMIT = Integer(ENV.fetch('CONTACT_RATE_LIMIT_PER_DAY', '20'))

Rack::Attack.throttle('contact form per 10 minutes', limit: CONTACT_BURST_LIMIT, period: 10.minutes) do |req|
  next unless req.post? && req.path == CONTACT_FORM_PATH

  req.ip
end

Rack::Attack.throttle('contact form per day', limit: CONTACT_DAILY_LIMIT, period: 1.day) do |req|
  next unless req.post? && req.path == CONTACT_FORM_PATH

  req.ip
end

# Whitelist specific IPs (e.g., internal services, CI/CD)
# Note: 'whitelist' is deprecated in Rack::Attack 6.x; using conditional skip instead
# or see https://github.com/rack/rack-attack/blob/master/lib/rack/attack/utils.rb
# Rack::Attack.throttle skip for localhost IPs within the throttle block

# Blocklist specific paths or patterns (optional)
# Rack::Attack.blocklist('block suspicious paths') do |req|
#   req.path.include?('/admin') && req.ip == 'known.bad.ip'
# end