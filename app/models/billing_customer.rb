# The one Stripe Customer that belongs to a billable owner (IDENTITY-116).
#
# The mapping is on the owner, not on the user who clicked Checkout: two Club
# administrators must resolve to the same Stripe Customer, and a Coach's personal
# Customer must never be reused for a club purchase. The unique index on the
# owner pair and on the Stripe ID are the real guarantees.
#
# Only identifiers are stored. No card number, CVC or payment credential is ever
# persisted by this application.
class BillingCustomer < ApplicationRecord
  OWNER_TYPES = %w[Account Organisation].freeze

  belongs_to :billable, polymorphic: true

  validates :billable_type, presence: true, inclusion: { in: OWNER_TYPES }
  validates :billable_id, uniqueness: { scope: :billable_type }
  validates :stripe_customer_id, presence: true, uniqueness: true

  scope :for_owner, ->(owner) { where(billable_type: owner.class.name, billable_id: owner.id) }
end
