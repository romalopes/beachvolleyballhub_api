# The canonical production site is always an allowed browser origin. Additional
# origins are configurable because FRONTEND_URL is also used for email links.
allowed_origins = ENV.fetch(
  "CORS_ORIGINS",
  ENV.fetch("FRONTEND_URL", "https://beachvolleyballhub.romalopes.workers.dev")
).split(",").map(&:strip).reject(&:blank?)

allowed_origins << "https://beachvolleyballhub.com"
allowed_origins.uniq!

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