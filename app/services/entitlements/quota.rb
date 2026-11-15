module Entitlements
  # Quota semantics for plan limits (IDENTITY-116, Phase 9).
  #
  #   nil  — unlimited / not applicable to this owner or limit
  #   0    — none beyond the documented owner access
  #   n>0  — an explicit maximum
  #
  # The framework is built now even though the launched catalogue sets both limits
  # to 0: a limit is a business decision, and the code must not invent one by
  # treating zero as "unlimited" (the classic off-by-a-meaning bug).
  class Quota
    class << self
      def unlimited?(limit)
        limit.nil?
      end

      # True only for a finite limit that has been reached or passed. Unlimited
      # never exceeds; zero exceeds as soon as there is any usage.
      def exceeded?(limit:, usage:)
        return false if unlimited?(limit)

        usage.to_i >= limit.to_i
      end

      def remaining(limit:, usage:)
        return nil if unlimited?(limit)

        [ limit.to_i - usage.to_i, 0 ].max
      end

      def describe(limit)
        return "unlimited" if unlimited?(limit)
        return "none" if limit.to_i.zero?

        limit.to_i.to_s
      end
    end
  end
end
