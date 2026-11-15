module Billing
  # Structured, secret-free operational logging for the billing integration
  # (IDENTITY-116, Phase 10).
  #
  # One JSON line per event so Render/host log search can filter on
  # `event=billing.*`. The helpers deliberately take a small allow-list of
  # identifiers — owner type/id, local record id, Stripe ids, correlation id — and
  # never an email, card detail or secret.
  module AuditLogger
    class << self
      def event(name, **payload)
        write(:info, name, payload)
      end

      def warn_event(name, **payload)
        write(:warn, name, payload)
      end

      def error_event(name, error = nil, **payload)
        payload = payload.merge(error_class: error.class.name, error: error&.message)
        write(:error, name, payload)
      end

      private

      def write(level, name, payload)
        entry = { event: "billing.#{name}", at: Time.current.utc.iso8601 }.merge(payload.compact)
        Rails.logger.public_send(level, entry.to_json)
      rescue StandardError => e
        # Logging must never break a payment flow.
        Rails.logger.warn("billing audit logger failed: #{e.class}: #{e.message}")
      end
    end
  end
end
