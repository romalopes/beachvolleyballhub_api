require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local
  config.active_storage.service = :cloudflare_r2

# Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV["BEHIND_HTTPS_PROXY"] == "true"
# Skip http-to-https redirect for the default health check endpoint.
  config.force_ssl = ENV["BEHIND_HTTPS_PROXY"] == "true"

  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      domain: ENV.fetch("SMTP_DOMAIN", "localhost"),
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true",
      open_timeout: 10,
      read_timeout: 10
    }
  end

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Trust Cloudflare edge IPs so `request.remote_ip` resolves the real client
  # address behind Cloudflare / Render instead of the load balancer. Cloudflare
  # publishes these ranges at https://www.cloudflare.com/ips/
  CF_RANGES = %w[
    173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22
    141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20
    197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
    104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32
    2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
  ].map { |cidr| IPAddr.new(cidr) }

  config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + CF_RANGES

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com"), protocol: "https" }

  # React frontend URL for password-reset email links (production deploy to Vercel).

  # Allow comma-separated production hostnames configured by the deployment.
  ENV.fetch("ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:blank?).each do |host|
    config.hosts << host
  end

  # Allow local testing in production mode.
  if ENV["ALLOW_LOCALHOST_IN_PRODUCTION"] == "true"
    config.hosts << "localhost"
    config.hosts << "127.0.0.1"
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
