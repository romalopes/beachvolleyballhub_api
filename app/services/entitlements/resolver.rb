module Entitlements
  # The single source of truth for "what may this owner use?" (IDENTITY-116,
  # Phase 2/8).
  #
  # Every API check goes through this class. Nothing else — no controller, no
  # policy, no React route guard — is allowed to interpret subscription status
  # independently. That is what keeps the pricing page, the API and the webhook
  # from disagreeing about what a plan includes.
  #
  # Rules, in order:
  #   1. No billing record, or no paid entitlement, means the default FREE plan.
  #   2. `active` and `trialing` grant the paid plan's features.
  #   3. `past_due` grants them only while the configured grace window is open.
  #   4. `canceled`, `unpaid`, `incomplete`, `incomplete_expired` and `paused`
  #      never grant paid features.
  #   5. A cancellation requested for period end keeps access until
  #      `current_period_end`.
  #   6. An inactive/retired plan is treated as no paid entitlement, never as
  #      "everything the old plan had".
  #
  # Deliberately no caching yet: entitlements are read on request paths where a
  # stale answer is worse than one indexed query. Add caching only with explicit
  # invalidation on webhook confirmation.
  class Resolver
    attr_reader :owner, :now

    def initialize(owner, now: Time.current)
      @owner = normalize_owner(owner)
      @now = now
    end

    # Returns a Resolver for a User, Account, Organisation or nil.
    def self.for(owner, now: Time.current)
      new(owner, now: now)
    end

    def self.feature_enabled?(owner, feature_slug, now: Time.current)
      new(owner, now: now).feature_enabled?(feature_slug)
    end

    def billing_record
      return @billing_record if defined?(@billing_record)

      # Read the record directly rather than through the owner association: an
      # association loaded earlier in the request (or in a test) would return a
      # stale status after a webhook transition. Entitlement correctness is worth
      # one indexed query; there is deliberately no cache here.
      @billing_record = if owner
        BillingSubscription.find_by(billable_type: owner.class.name, billable_id: owner.id)
      end
    end

    def status
      billing_record&.status || "free"
    end

    def entitled?
      entitled_record?(billing_record)
    end

    def free_fallback?
      !entitled?
    end

    # The plan whose features currently apply. FREE when not entitled.
    def plan
      @plan ||= entitled? ? billing_record.subscription : free_plan
    end

    def effective_features
      @effective_features ||= plan ? plan.features.active.ordered.to_a : []
    end

    def effective_feature_slugs
      effective_features.map(&:slug)
    end

    def feature_enabled?(feature_slug)
      return false if feature_slug.blank?

      effective_features.any? { |feature| feature.slug == feature_slug.to_s }
    end

    # nil means unlimited / not applicable, 0 means none, n > 0 is a quota.
    # Values come from the plan catalogue only, never from client input.
    def limit_for(limit_name)
      return nil unless plan

      plan.public_send(normalize_limit_name(limit_name))
    end

    def usage_for(limit_name)
      Usage.value_for(owner, normalize_limit_name(limit_name))
    end

    def exceeded?(limit_name, usage: nil)
      limit = limit_for(limit_name)
      Quota.exceeded?(limit: limit, usage: usage.nil? ? usage_for(limit_name) : usage)
    end

    # The cheapest active, visible plan that grants a feature — the upgrade hint
    # returned with a 403, with no payment or subscription detail in it.
    def suggested_plan_for(feature_slug)
      return nil if feature_slug.blank?

      Subscription.visible_and_active.ordered.detect do |candidate|
        candidate.features.active.exists?(slug: feature_slug.to_s)
      end
    end

    def summary
      {
        owner_type: owner&.class&.name,
        owner_id: owner&.id,
        plan_slug: plan&.slug,
        status: status,
        entitled: entitled?,
        free_fallback: free_fallback?,
        feature_slugs: effective_feature_slugs,
        effective_until: billing_record&.current_period_end,
        cancel_at_period_end: billing_record&.cancel_at_period_end? || false,
        grace_period_ends_at: billing_record&.grace_period_ends_at
      }
    end

    private

    def normalize_owner(value)
      return value if value.is_a?(Account) || value.is_a?(Organisation)
      return value.account if value.respond_to?(:account)

      nil
    end

    def free_plan
      @free_plan ||= Subscription.default_plan
    end

    def entitled_record?(record)
      return false unless record

      plan = record.subscription
      return false unless plan&.active?

      case record.status
      when "active", "trialing"
        # A cancellation requested for period end keeps access until the period
        # really ends. A webhook normally flips the status before then; this
        # guard covers the delivery gap.
        !(record.cancel_at_period_end? && record.current_period_end.present? &&
          record.current_period_end <= now)
      when "past_due"
        record.within_grace_period?(now)
      else
        false
      end
    end

    def normalize_limit_name(limit_name)
      name = limit_name.to_sym
      unless %i[included_users history_limit].include?(name)
        raise ArgumentError, "Unknown subscription limit: #{limit_name}"
      end

      name
    end
  end
end
