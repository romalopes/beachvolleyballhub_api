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
allowed_origins << "https://beachvolleyballhub.com"
allowed_origins << "https://www.beachvolleyballhub.com"
allowed_origins << "https://beachvolleyballhub.romalopes.workers.dev"
allowed_origins << "http://localhost:5174"
allowed_origins << "http://localhost:3001"
allowed_origins << "http://192.168.1.25:5174"
allowed_origins << "http://192.168.1.105:5174"
allowed_origins << "http://192.168.1.6:5174"
allowed_origins << "http://192.168.1.103:5174"
allowed_origins << "http://192.168.1.105:5174"
allowed_origins << "http://192.168.1.104:5174"

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end