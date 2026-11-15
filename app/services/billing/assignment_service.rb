module Billing
  # Manually assigns a plan to an owner, for support and migration work
  # (IDENTITY-116, Phase 4 admin surface).
  #
  # Deliberately narrow: a reason is mandatory, every assignment writes a history
  # row and an audit log entry, and a subscription that Stripe manages is *not*
  # overwritten locally — that would be reverted by the next webhook and would
  # make the two systems disagree in the meantime. Cancel or change it in Stripe
  # instead.
  class AssignmentService
    def initialize(actor:, owner_type:, owner_id:, plan_slug:, reason:)
      @actor = actor
      @owner_type = owner_type.to_s
      @owner_id = owner_id
      @plan_slug = plan_slug.to_s
      @reason = reason.to_s.strip
    end

    attr_reader :actor, :owner_type, :owner_id, :plan_slug, :reason

    def call
      raise Errors::BillingError.new("An audit reason is required",
                                     code: "audit_reason_required") if reason.blank?

      owner = resolve_owner
      plan = Subscription.find_by(slug: plan_slug)
      raise Errors::PlanNotPurchasable, "Unknown plan #{plan_slug.inspect}" if plan.nil?
      unless plan.supports_owner?(owner.class.name)
        raise Errors::PlanIncompatible
      end

      record = BillingSubscription.find_or_initialize_by(
        billable_type: owner.class.name, billable_id: owner.id
      )
      if record.persisted? && record.stripe_managed?
        raise Errors::BillingError.new(
          "This subscription is managed by Stripe; change or cancel it there",
          code: "subscription_stripe_managed"
        )
      end

      previous_plan = record.subscription
      record.assign_attributes(
        subscription: plan,
        status: "active",
        canceled_at: nil,
        cancel_at_period_end: false,
        grace_period_ends_at: nil,
        ended_at: nil,
        last_synced_at: Time.current,
        metadata: record.metadata.to_h.merge(
          "last_admin_assignment" => {
            "plan_slug" => plan.slug,
            "reason" => reason,
            "actor_id" => actor&.id,
            "assigned_at" => Time.current.iso8601
          }
        )
      )
      record.save!

      HistoryRecorder.record!(
        billable: owner,
        plan: plan,
        previous_plan: previous_plan,
        status: "active",
        source: "admin",
        stripe_subscription_id: record.stripe_subscription_id,
        stripe_price_id: record.stripe_price_id,
        started_at: Time.current,
        metadata: { "reason" => reason, "actor_id" => actor&.id }
      )

      AuditLogger.event("admin.assignment",
                        owner_type: owner.class.name, owner_id: owner.id,
                        plan_slug: plan.slug, actor_id: actor&.id, reason: reason)
      record
    end

    private

    def resolve_owner
      unless BillingSubscription::OWNER_TYPES.include?(owner_type)
        raise Errors::BillingError.new("owner_type must be Account or Organisation",
                                       code: "invalid_owner_type")
      end

      owner = owner_type.constantize.find_by(id: owner_id)
      raise Errors::BillingError.new("Owner not found", code: "owner_not_found",
                                     status: :not_found) if owner.nil?

      owner
    end
  end
end
