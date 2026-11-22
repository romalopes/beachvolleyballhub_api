# SEC-09: the private test-access gate is open when TEST_ACCESS_PASSWORD is
# unset (intentional for development/CI). In production that silently removes a
# defense layer, so surface it loudly at boot instead of failing silently.
Rails.application.config.after_initialize do
  if Rails.env.production? && ENV["TEST_ACCESS_PASSWORD"].blank?
    Rails.logger.warn(
      "[security] TEST_ACCESS_PASSWORD is unset in production — the private " \
      "test-access gate is DISABLED. Set it (or confirm this is intended)."
    )
  end
end
