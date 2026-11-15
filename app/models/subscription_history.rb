# Append-only lifecycle history for a billable owner (IDENTITY-116).
#
# A row is written for a meaningful transition: a paid plan activated, a plan
# changed, a renewal recorded, a cancellation applied, an admin assignment. It
# names the plan that was replaced so "which plan did this club have before the
# upgrade?" is answerable without reconstructing Stripe's event log.
#
# Rows are immutable once persisted. Corrections are new rows, never edits, so
# the audit trail cannot be rewritten in place.
class SubscriptionHistory < ApplicationRecord
  OWNER_TYPES = %w[Account Organisation].freeze
  SOURCES = %w[checkout webhook admin migration reconciliation].freeze

  belongs_to :billable, polymorphic: true
  belongs_to :subscription
  belongs_to :previous_subscription, class_name: "Subscription", optional: true

  validates :billable_type, presence: true, inclusion: { in: OWNER_TYPES }
  validates :status, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_owner, ->(owner) {
    where(billable_type: owner.class.name, billable_id: owner.id)
  }

  def readonly?
    persisted?
  end
end
