# Fail fast at boot if the Solid Cache table is missing in production.
#
# Background: Rails 8 `rate_limit` (used by POST /api/v1/sessions,
# registrations, passwords, ...) writes through `Rails.cache`, which in
# production is `:solid_cache_store` backed by the `cache` database
# (see config/cache.yml + config/database.yml). If `db:migrate:cache` never
# ran (e.g. Docker deploy without preDeployCommand), every rate-limited
# endpoint 500s with:
#   PG::UndefinedTable: relation "solid_cache_entries" does not exist
#
# This check runs AFTER migrations in a normal deploy (preDeployCommand, then
# boot), so it only fires when the deploy pipeline is misconfigured — and its
# message tells the operator exactly what to run. It is a no-op in
# development/test and when the cache store is not Solid Cache.
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  next unless Rails.cache.is_a?(ActiveSupport::Cache::Store)
  next unless defined?(SolidCache::Entry)

  begin
    SolidCache::Entry.without_query_cache do
      unless SolidCache::Entry.table_exists?
        raise <<~MSG
          [cache_health_check] solid_cache_entries table is MISSING in production.
          Every `rate_limit` endpoint (POST /api/v1/sessions, registrations, passwords, ...)
          will 500 with PG::UndefinedTable.
          Fix (Render Shell with prod env):
            bundle exec rails db:migrate db:migrate:cache db:migrate:queue db:migrate:cable
          Then verify: bundle exec rails db:migrate:status:cache shows `up`.
          Durable fix: ensure render.yaml preDeployCommand (./bin/render-predeploy.sh)
          is applied (Blueprint sync) or set manually on the Render service.
        MSG
      end
    end
  rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad => e
    # Database unreachable at boot (e.g. build phase without DATABASE_URL):
    # log and continue — Puma boot should not crash the image build.
    Rails.logger.warn("[cache_health_check] skipping: database unreachable (#{e.class}: #{e.message})")
  end
end
