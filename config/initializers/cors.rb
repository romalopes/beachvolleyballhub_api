# Comma-separated exact origins for deployed browser clients. FRONTEND_URL is
# retained as the fallback because it is also used in email links.
allowed_origins = ENV.fetch(
  "CORS_ORIGINS",
  ENV.fetch("FRONTEND_URL", "https://beachvolleyballhub.romalopes.workers.dev")
).split(",").map(&:strip).reject(&:blank?)

# Local development is intentionally opt-in by environment rather than exposed
# by the production allow-list.
if Rails.env.development?
  allowed_origins.concat([ "http://localhost:5174", "http://localhost:3001" ])
end

# Cloudflare Workers preview deployments are an intended frontend surface.
allowed_origins << %r{\Ahttps://[a-zA-Z0-9-]+-beachvolleyballhub\.romalopes\.workers\.dev\z}

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end