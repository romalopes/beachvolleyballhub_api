module Billing
  # Verifies that a configured Stripe Price really is the yearly AUD price the
  # catalogue claims (IDENTITY-116, Phase 3).
  #
  # This check runs when a Checkout Session is about to be created — the one moment
  # where a misconfigured live key could charge the wrong amount or interval. It
  # never trusts the catalogue numbers for billing; Stripe's Price is authoritative.
  class PriceValidator
    class << self
      def validate!(plan, price_id = nil)
        price_id ||= PriceCatalog.require_price_id!(plan)
        price = StripeGateway.retrieve_price(price_id)
        currency = price.respond_to?(:currency) ? price.currency.to_s.upcase : price.dig("currency").to_s.upcase
        interval = if price.respond_to?(:recurring)
          price.recurring&.interval
        else
          price.dig("recurring", "interval")
        end

        unless currency == Configuration::DEFAULT_CURRENCY && interval.to_s == "year"
          raise Errors::InvalidPrice,
                "The configured Stripe Price for #{plan.slug} must be #{Configuration::DEFAULT_CURRENCY} and recur yearly"
        end

        true
      rescue Stripe::StripeError => e
        raise Errors::TransientFailure, "Could not verify the Stripe Price: #{e.message}"
      end
    end
  end
end
