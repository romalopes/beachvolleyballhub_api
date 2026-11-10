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

# Whitelist specific IPs (e.g., internal services, CI/CD)
# Note: 'whitelist' is deprecated in Rack::Attack 6.x; using conditional skip instead
# or see https://github.com/rack/rack-attack/blob/master/lib/rack/attack/utils.rb
# Rack::Attack.throttle skip for localhost IPs within the throttle block

# Blocklist specific paths or patterns (optional)
# Rack::Attack.blocklist('block suspicious paths') do |req|
#   req.path.include?('/admin') && req.ip == 'known.bad.ip'
# end