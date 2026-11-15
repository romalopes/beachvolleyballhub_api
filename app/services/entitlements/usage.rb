module Entitlements
  # Counts current usage for a quota (IDENTITY-116, Phase 9).
  #
  # Usage is always scoped to the owner that holds the subscription. Personal and
  # organisation usage never mix: a Coach's personal plan says nothing about a
  # club's seats, and a Club's seats are not spent by the club's owner personally.
  #
  #   included_users — active memberships of the organisation. Not applicable to a
  #                    personal Account, whose owner is not a seat.
  #   history_limit  — lifecycle history rows retained for the owner.
  #
  # Nothing here deletes or archives data; exceeding a limit must restrict the
  # next operation, never destroy what already exists.
  module Usage
    class << self
      def value_for(owner, limit_name)
        case limit_name.to_sym
        when :included_users then included_users(owner)
        when :history_limit then history_rows(owner)
        else
          raise ArgumentError, "Unknown subscription limit: #{limit_name}"
        end
      end

      def included_users(owner)
        return nil unless owner.is_a?(Organisation)

        owner.organisation_memberships.active.count
      end

      def history_rows(owner)
        return 0 unless owner

        SubscriptionHistory
          .where(billable_type: owner.class.name, billable_id: owner.id)
          .count
      end

      def summary(owner)
        resolver = Resolver.new(owner)
        %i[included_users history_limit].to_h do |limit_name|
          limit = resolver.limit_for(limit_name)
          used = value_for(owner, limit_name)
          [
            limit_name,
            {
              limit: limit,
              usage: used,
              remaining: used.nil? ? nil : Quota.remaining(limit: limit, usage: used),
              unlimited: Quota.unlimited?(limit),
              exceeded: used.nil? ? false : Quota.exceeded?(limit: limit, usage: used)
            }
          ]
        end
      end
    end
  end
end
