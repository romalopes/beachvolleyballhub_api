Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Capture 100% of transactions in dev/staging; lower in high-traffic production
  config.traces_sample_rate = Rails.env.production? ? 0.2 : 1.0

  # Filter out predictable or noisy exceptions
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound'
  ]
end



# # wine_words_api/config/initializers/sentry.rb
# Sentry.init do |config|
#   config.dsn = ENV['SENTRY_DSN']
#   config.breadcrumbs_logger = [:active_support_logger, :http_logger]

#   # -----------------------------------------------------------------
#   # Parameter & header scrubbing via before_send (works with sentry‑ruby 7.1.0)
#   # -----------------------------------------------------------------
#   config.before_send = lambda do |event, hint|
#     # ---- Scrub request parameters ----
#     if event[:request] && event[:request][:params].is_a?(Hash)
#       event[:request][:params].each do |key, value|
#         if key.to_s.match?(/^(password|password_confirmation|credit_card|cc_number)$/i)
#           event[:request][:params][key] = '[FILTERED]'
#         end
#       end
#     end

#     # ---- Scrub request headers (Authorization, Cookie, etc.) ----
#     if event[:request] && event[:request][:headers].is_a?(Hash)
#       event[:request][:headers].each do |key, value|
#         if key.to_s.match?(/^(authorization|cookie)$/i)
#           event[:request][:headers][key] = '[FILTERED]'
#         end
#       end
#     end

#     # ---- Scrub user context (optional) ----
#     if event[:user] && event[:user].is_a?(Hash)
#       event[:user].each do |key, value|
#         if key.to_s.match?(/^(email|username)$/i)
#           event[:user][key] = '[FILTERED]'
#         end
#       end
#     end

#     # Return the (potentially mutated) event; returning nil would drop it.
#     event
#   end

#   # -----------------------------------------------------------------
#   # Existing settings (keep them unchanged)
#   # -----------------------------------------------------------------
#   # Capture 100% of transactions in dev/staging; lower in high‑traffic production
#   config.traces_sample_rate = Rails.env.production? ? 0.2 : 1.0

#   # Filter out predictable or noisy exceptions
#   config.excluded_exceptions += [
#     'ActionController::RoutingError',
#     'ActiveRecord::RecordNotFound'
#   ]
# end
