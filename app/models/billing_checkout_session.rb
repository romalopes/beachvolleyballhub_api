# Correlation record for a Stripe Checkout Session created by this API
# (IDENTITY-116, Phase 4/5).
#
# It exists so `checkout.session.completed` can be tied back to the internal
# billable owner and plan without trusting a query parameter, and so a repeated
# Checkout request can reuse an open session instead of creating a second one.
class BillingCheckoutSession < ApplicationRecord
  OWNER_TYPES = %w[Account Organisation].freeze
  STATUSES = %w[open completed expired canceled].freeze

  belongs_to :billable, polymorphic: true
  belongs_to :subscription

  validates :billable_type, presence: true, inclusion: { in: OWNER_TYPES }
  validates :stripe_checkout_session_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :open_sessions, -> { where(status: "open") }
  scope :recent, -> { order(created_at: :desc) }

  def completed?
    status == "completed"
  end

  def reusable?(now = Time.current)
    status == "open" && expires_at.present? && expires_at > now && url.present?
  end

  def mark_completed!(now = Time.current)
    update!(status: "completed", completed_at: now)
  end
end
