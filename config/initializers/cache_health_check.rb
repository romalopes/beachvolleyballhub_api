# Advisory check: warn (never crash) if the Solid Cache table is missing.
#
# Background: Rails 8 `rate_limit` (POST /api/v1/sessions, registrations,
# passwords, ...) writes through `Rails.cache`, which in production is
# `:solid_cache_store` backed by the `cache` database. If `db:migrate:cache`
# never ran, rate-limited endpoints 500 with:
#   PG::UndefinedTable: relation "solid_cache_entries" does not exist
#
# Deliberately log-and-continue: crashing boot takes down even the healthy
# non-rate-limited endpoints. The missing-table error in request logs plus
# this boot warning point at the same fix (run the migrates below).
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
    missing = false
    begin
      missing = !SolidCache::Entry.table_exists?
    rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
      missing = true if e.message.include?("solid_cache_entries")
      raise unless missing
    end
    if missing
      Rails.logger.error(
        "[cache_health_check] solid_cache_entries table is MISSING. " \
        "Rate-limited endpoints (POST /api/v1/sessions, ...) will 500. " \
        "Fix: bundle exec rails db:migrate db:migrate:cache db:migrate:queue db:migrate:cable"
      )
    end
  rescue StandardError => e
    # Future-proof: any other API/adapter change degrades to a warning so the
    # image build and Puma boot never crash on this advisory check.
    Rails.logger.warn("[cache_health_check] skipping advisory check (#{e.class}: #{e.message.lines.first})")
  end
end
