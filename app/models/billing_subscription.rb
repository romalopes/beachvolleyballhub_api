# The current subscription record for one billable owner (IDENTITY-116).
#
# One row per owner, unique on (billable_type, billable_id). This is a *mirror* of
# Stripe's canonical subscription state — the webhook and reconciliation service
# write it, and the entitlement resolver reads it. It is never written
# optimistically from a browser redirect or from an unconfirmed API call.
#
# Statuses are Stripe's, not a boolean. `active`/`trialing` grant paid features;
# `past_due` grants them only inside the configured grace window; `canceled`,
# `unpaid`, `incomplete` and `incomplete_expired` do not. `cancel_at_period_end`
# keeps access until `current_period_end`.
#
# `pending_subscription_id` records a requested change (upgrade/downgrade) that
# Stripe has not confirmed yet. The plan in `subscription_id` remains the current
# entitlement until the webhook reports the new Price.
class BillingSubscription < ApplicationRecord
  OWNER_TYPES = %w[Account Organisation].freeze
  STATUSES = %w[
    incomplete incomplete_expired trialing active past_due canceled unpaid paused
  ].freeze
  # Statuses that grant paid access without a grace check.
  ENTITLED_STATUSES = %w[active trialing].freeze
  # Statuses from which no paid access is granted, whatever the period says.
  BLOCKED_STATUSES = %w[incomplete incomplete_expired unpaid canceled paused].freeze

  belongs_to :billable, polymorphic: true
  belongs_to :subscription
  belongs_to :pending_subscription, class_name: "Subscription", optional: true
  has_many :histories,
           class_name: "SubscriptionHistory",
           as: :billable,
           dependent: :restrict_with_error

  validates :billable_type, presence: true, inclusion: { in: OWNER_TYPES }
  validates :billable_id, uniqueness: { scope: :billable_type }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :subscription_id, presence: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  scope :stripe_managed, -> { where.not(stripe_subscription_id: nil) }
  scope :entitled_status, -> { where(status: ENTITLED_STATUSES) }
  scope :stale_since, ->(time) { where("last_synced_at IS NULL OR last_synced_at < ?", time) }

  def plan
    subscription
  end

  def stripe_managed?
    stripe_subscription_id.present?
  end

  def paid_status?
    ENTITLED_STATUSES.include?(status)
  end

  def blocked_status?
    BLOCKED_STATUSES.include?(status)
  end

  def past_due?
    status == "past_due"
  end

  def within_grace_period?(now = Time.current)
    return false unless past_due?

    grace_period_ends_at.present? && grace_period_ends_at > now
  end

  # True while the paid period is still running. Used to keep access after a
  # cancellation request, and to decide whether a deferred downgrade has become
  # due.
  def period_running?(now = Time.current)
    current_period_end.present? && current_period_end > now
  end

  def pending_change?
    pending_subscription_id.present?
  end

  def pending_change_applied?(new_plan_id)
    pending_subscription_id.present? && pending_subscription_id == new_plan_id
  end

  # Records that Stripe has confirmed a state change. Pending change data is
  # cleared whenever the plan in Stripe is the one that was pending.
  def apply_stripe_state!(attributes)
    assign_attributes(attributes)
    if pending_subscription_id.present? && subscription_id == pending_subscription_id
      self.pending_subscription_id = nil
      self.pending_change_requested_at = nil
      self.pending_change_effective_at = nil
    end
    self.last_synced_at = Time.current
    save!
  end
end
