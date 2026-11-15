module Billing
  # Upgrade, downgrade, cancellation and resumption (IDENTITY-116, Phase 6).
  #
  # Business rules:
  #   * upgrade   — immediate, Stripe-calculated proration, invoice collected now
  #   * downgrade — scheduled for the next renewal (no early loss of access)
  #   * cancel    — at period end
  #   * resume    — reverses a pending cancellation while the period is running
  #
  # In every case the *local* plan changes only when the webhook confirms Stripe's
  # new state. Until then the current entitlement is preserved, which is what stops
  # a failed upgrade payment from taking features away.
  class PlanChangeService
    ACTIONS = %w[change cancel resume].freeze

    def initialize(user:, action: "change", plan_slug: nil, owner_type: nil, owner_id: nil)
      @user = user
      @action = action.to_s.presence_in(ACTIONS) || "change"
      @plan_slug = plan_slug.to_s.strip
      @owner_type = owner_type
      @owner_id = owner_id
    end

    attr_reader :user, :action, :plan_slug, :owner_type, :owner_id

    def call
      Configuration.validate_api!
      owner = OwnerResolver.new(user).resolve(owner_type: owner_type, owner_id: owner_id)
      record = BillingSubscription.find_by(billable_type: owner.class.name, billable_id: owner.id)
      raise Errors::NoActiveSubscription unless record&.stripe_managed?
      raise Errors::NoActiveSubscription if record.status == "canceled"

      case action
      when "cancel" then cancel!(owner, record)
      when "resume" then resume!(owner, record)
      else change_plan!(owner, record)
      end
    end

    private

    def change_plan!(owner, record)
      plan = Subscription.visible_and_active.find_by(slug: plan_slug)
      raise Errors::PlanNotPurchasable unless plan&.purchasable?
      raise Errors::PlanIncompatible unless plan.supports_owner?(owner.class.name)

      record.with_lock do
        raise Errors::SamePlan if plan.id == record.subscription_id
        if record.pending_change? && record.pending_change_requested_at.present? &&
           record.pending_change_requested_at > 10.minutes.ago
          raise Errors::ChangeAlreadyPending
        end

        upgrade = plan.yearly_price_cents > record.subscription.yearly_price_cents
        apply_stripe_change!(record, plan, upgrade)

        record.update!(
          pending_subscription_id: plan.id,
          pending_change_requested_at: Time.current,
          pending_change_effective_at: upgrade ? Time.current : record.current_period_end
        )

        AuditLogger.event("plan_change.requested",
                          owner_type: owner.class.name, owner_id: owner.id,
                          from: record.subscription.slug, to: plan.slug,
                          kind: upgrade ? "upgrade" : "downgrade",
                          stripe_subscription_id: record.stripe_subscription_id)

        {
          status: "pending_confirmation",
          action: upgrade ? "upgrade" : "downgrade",
          plan_slug: plan.slug,
          effective_at: upgrade ? Time.current : record.current_period_end,
          message: (upgrade ? "Stripe is confirming the upgrade and collecting the prorated amount." : "The new plan takes effect at the next renewal.")
        }
      end
    end

    def apply_stripe_change!(record, plan, upgrade)
      price_id = PriceCatalog.require_price_id!(plan)

      if upgrade
        item_id = StripeGateway.current_item_id(record.stripe_subscription_id)
        raise Errors::TransientFailure, "Could not read the Stripe subscription item" if item_id.blank?

        StripeGateway.update_subscription(record.stripe_subscription_id, {
          items: [ { id: item_id, price: price_id } ],
          proration_behavior: "always_invoice",
          cancel_at_period_end: false,
          metadata: { managed_by: "beachvolleyballhub", pending_plan_slug: plan.slug }
        })
      else
        StripeGateway.schedule_plan_change(
          subscription_id: record.stripe_subscription_id,
          new_price_id: price_id,
          effective_at: record.current_period_end
        )
      end
    end

    def cancel!(owner, record)
      unless record.cancel_at_period_end?
        StripeGateway.update_subscription(record.stripe_subscription_id, {
          cancel_at_period_end: true,
          metadata: { managed_by: "beachvolleyballhub", cancellation_requested: "true" }
        })
      end

      record.update!(metadata: record.metadata.merge("cancel_requested_at" => Time.current.iso8601))
      AuditLogger.event("subscription.cancel_requested",
                        owner_type: owner.class.name, owner_id: owner.id,
                        stripe_subscription_id: record.stripe_subscription_id,
                        effective_at: record.current_period_end)

      {
        status: "cancellation_requested",
        effective_at: record.current_period_end,
        message: "The subscription stays active until the end of the paid period."
      }
    end

    def resume!(owner, record)
      unless record.cancel_at_period_end?
        raise Errors::BillingError.new("This subscription is not scheduled to cancel",
                                       code: "subscription_not_cancelling")
      end

      StripeGateway.update_subscription(record.stripe_subscription_id, {
        cancel_at_period_end: false,
        metadata: { managed_by: "beachvolleyballhub" }
      })
      record.update!(metadata: record.metadata.except("cancel_requested_at"))
      AuditLogger.event("subscription.cancel_resumed",
                        owner_type: owner.class.name, owner_id: owner.id,
                        stripe_subscription_id: record.stripe_subscription_id)

      { status: "cancellation_reversed", message: "The subscription will renew as normal." }
    end
  end
end
