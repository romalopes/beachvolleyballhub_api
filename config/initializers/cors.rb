# Comma-separated exact origins for deployed browser clients. FRONTEND_URL is
# retained as the fallback because it is also used in email links.
allowed_origins = ENV.fetch(
  "CORS_ORIGINS",
  ENV.fetch("FRONTEND_URL", "https://beachvolleyballhub.romalopes.workers.dev")
).split(",").map(&:strip).reject(&:blank?)

# Deployed frontend surfaces (always allowed).
# Cloudflare Workers preview deployments are an intended frontend surface.
allowed_origins << %r{\Ahttps://[a-zA-Z0-9-]+-beachvolleyballhub\.romalopes\.workers\.dev\z}
allowed_origins << "https://beachvolleyballhub.com"
allowed_origins << "https://www.beachvolleyballhub.com"
allowed_origins << "https://beachvolleyballhub.romalopes.workers.dev"

# Local development origins are intentionally opt-in by environment only, so the
# production allow-list never includes localhost or private LAN addresses.
if Rails.env.development?
  allowed_origins.concat([
    "http://localhost:5174",
    "http://localhost:3001"
  ])
  # Optional LAN testing override (e.g. hitting the dev server from a phone).
  # Set DEV_CORS_ORIGINS="http://192.168.1.25:5174,http://192.168.1.104:5174".
  ENV.fetch("DEV_CORS_ORIGINS", "").split(",").map(&:strip).reject(&:blank?).each do |origin|
    allowed_origins << origin
  end
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end
