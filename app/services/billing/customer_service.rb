module Billing
  # One Stripe Customer per billable owner (IDENTITY-116, Phase 4).
  #
  # Creating the customer is the only step here that talks to Stripe. The local
  # mapping is written immediately afterwards, and the unique index on
  # (billable_type, billable_id) makes a concurrent double-create safe: the loser
  # reads the winner's row instead of producing a second Stripe Customer.
  class CustomerService
    class << self
      # Returns the BillingCustomer for +owner+, creating the Stripe Customer on
      # first use.
      def for(owner)
        existing = BillingCustomer.find_by(billable_type: owner.class.name, billable_id: owner.id)
        return existing if existing

        Configuration.validate_api!
        stripe_customer = StripeGateway.create_customer(
          email: OwnerContact.email(owner),
          name: OwnerContact.name(owner),
          metadata: { owner_type: owner.class.name, owner_id: owner.id }
        )

        BillingCustomer.create!(
          billable: owner,
          stripe_customer_id: stripe_customer.id,
          email: OwnerContact.email(owner)
        )
      rescue ActiveRecord::RecordNotUnique
        BillingCustomer.find_by!(billable_type: owner.class.name, billable_id: owner.id)
      end

      # Finds the owner a Stripe Customer belongs to. Returns nil for a customer
      # this application never created — the webhook treats that as a mismatch.
      def owner_for_stripe_customer(stripe_customer_id)
        return nil if stripe_customer_id.blank?

        BillingCustomer.find_by(stripe_customer_id: stripe_customer_id.to_s)&.billable
      end
    end
  end
end
