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
# development/test, during asset builds, and when the cache store is not
# Solid Cache.
Rails.application.config.after_initialize do
  # NEVER touch the DB during image build: Dockerfile runs
  # `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` with
  # RAILS_ENV=production and no DATABASE_URL. Any DB call here aborts the
  # build (this previously broke `build 7/7` via a private-method call).
  next if ENV["SECRET_KEY_BASE_DUMMY"].present?
  next if ARGV.any? { |a| a.start_with?("assets:") }
  next unless Rails.env.production?
  next unless Rails.cache.is_a?(ActiveSupport::Cache::Store)
  next unless defined?(SolidCache::Entry)

  begin
    # Public API only: `table_exists?` on the model resolves to the `cache`
    # database connection automatically. Do NOT call the private
    # `SolidCache::Entry.without_query_cache`.
    # NOTE: on Postgres, `table_exists?` itself can raise PG::UndefinedTable
    # (the `'"solid_cache_entries"'::regclass` cast fails when the table is
    # missing) — that means "missing", not "unknown error".
    exists = SolidCache::Entry.table_exists?
    unless exists
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
  rescue RuntimeError
    # Our intentional loud failure above — never swallow it.
    raise
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable, PG::ConnectionBad,
         ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished => e
    # Missing table surfaces as StatementInvalid/UndefinedTable on PG;
    # unreachable DB surfaces as ConnectionBad/NoDatabaseError (e.g. build
    # phase without DATABASE_URL). Missing => loud raise; unreachable => warn.
    if e.message.include?("solid_cache_entries")
      raise <<~MSG
        [cache_health_check] solid_cache_entries table is MISSING in production.
        Every `rate_limit` endpoint (POST /api/v1/sessions, registrations, passwords, ...)
        will 500 with PG::UndefinedTable.
        Fix (Render Shell with prod env):
          bundle exec rails db:migrate db:migrate:cache db:migrate:queue db:migrate:cable
        Then verify: bundle exec rails db:migrate:status:cache shows `up`.
        Durable fix: ensure render.yaml preDeployCommand (./bin/render-predeploy.sh)
        is applied (Blueprint sync) or set manually on the Render service.
        (Original error: #{e.class}: #{e.message.lines.first})
      MSG
    end
    Rails.logger.warn("[cache_health_check] skipping: database unreachable (#{e.class}: #{e.message.lines.first})")
  rescue StandardError => e
    # Future-proof: any other API/adapter change degrades to a warning so the
    # image build and Puma boot never crash on this advisory check.
    Rails.logger.warn("[cache_health_check] skipping advisory check (#{e.class}: #{e.message.lines.first})")
  end
end
