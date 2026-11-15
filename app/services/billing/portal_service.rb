module Billing
  # Opens the Stripe Customer Portal for the owner's existing Customer
  # (IDENTITY-116, Phase 4/6).
  #
  # Payment-method updates, invoice downloads and — where configured in Stripe —
  # cancellation all happen in Stripe's hosted portal, so this application never
  # handles card data. The portal session is scoped to the owner's own Customer;
  # an owner without one is told to subscribe first rather than having a Customer
  # created just to open an empty portal.
  class PortalService
    def initialize(user:, owner_type: nil, owner_id: nil)
      @user = user
      @owner_type = owner_type
      @owner_id = owner_id
    end

    attr_reader :user, :owner_type, :owner_id

    def call
      owner = OwnerResolver.new(user).resolve(owner_type: owner_type, owner_id: owner_id)
      customer = BillingCustomer.find_by(billable_type: owner.class.name, billable_id: owner.id)
      if customer.nil?
        raise Errors::BillingError.new("There is no Stripe billing account for this owner yet",
                                       code: "billing_customer_missing")
      end

      session = StripeGateway.create_portal_session(
        customer: customer.stripe_customer_id,
        return_url: Configuration.portal_return_url
      )

      AuditLogger.event("portal.created",
                        owner_type: owner.class.name, owner_id: owner.id,
                        customer_id: customer.stripe_customer_id)

      { url: session.url }
    end
  end
end
