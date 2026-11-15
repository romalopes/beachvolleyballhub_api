module Billing
  # Starts a paid subscription through Stripe Checkout (IDENTITY-116, Phase 4).
  #
  # The browser sends a *plan slug* and (optionally) an owner type/id. It never
  # sends a Price ID, amount or currency: those are resolved here from trusted
  # server configuration. A Checkout Session is created in `subscription` mode and
  # the local correlation row is persisted before the URL is returned.
  #
  # Creating the session does not grant anything. The subscription becomes active
  # only when a signed webhook reports it.
  class CheckoutService
    Result = Struct.new(:url, :session_id, :checkout_session, :reused, keyword_init: true)

    # An open session younger than this is handed back instead of creating a new
    # one — a double click must not produce two Stripe sessions.
    REUSE_WINDOW = 30.minutes

    def initialize(user:, plan_slug:, owner_type: nil, owner_id: nil)
      @user = user
      @plan_slug = plan_slug.to_s.strip
      @owner_type = owner_type
      @owner_id = owner_id
    end

    attr_reader :user, :plan_slug, :owner_type, :owner_id

    def call
      Configuration.validate_api!
      owner = OwnerResolver.new(user).resolve(owner_type: owner_type, owner_id: owner_id)
      plan = find_plan!
      validate_plan!(plan, owner)
      ensure_not_already_subscribed!(owner)

      reusable = reusable_checkout(owner, plan)
      if reusable
        AuditLogger.event("checkout.reused",
                          owner_type: owner.class.name, owner_id: owner.id,
                          session_id: reusable.stripe_checkout_session_id)
        return Result.new(url: reusable.url, session_id: reusable.stripe_checkout_session_id,
                          checkout_session: reusable, reused: true)
      end

      price_id = PriceCatalog.require_price_id!(plan)
      PriceValidator.validate!(plan, price_id)
      customer = CustomerService.for(owner)
      session = create_stripe_session(owner, plan, price_id, customer)
      record = persist_checkout(owner, plan, customer, session)

      AuditLogger.event("checkout.created",
                        owner_type: owner.class.name, owner_id: owner.id,
                        plan_slug: plan.slug, session_id: session.id,
                        price_id: price_id)

      Result.new(url: session.url, session_id: session.id, checkout_session: record, reused: false)
    end

    private

    def find_plan!
      plan = Subscription.visible_and_active.find_by(slug: plan_slug)
      raise Errors::PlanNotPurchasable unless plan&.purchasable?

      plan
    end

    def validate_plan!(plan, owner)
      raise Errors::PlanIncompatible unless plan.supports_owner?(owner.class.name)
    end

    def ensure_not_already_subscribed!(owner)
      # Direct query: an association loaded earlier in the request could be stale
      # after a webhook transition.
      record = BillingSubscription.find_by(billable_type: owner.class.name, billable_id: owner.id)
      return if record.blank?
      return if record.status == "canceled" && record.ended_at.present?
      return unless record.stripe_managed?

      raise Errors::AlreadySubscribed
    end

    def reusable_checkout(owner, plan)
      BillingCheckoutSession.open_sessions
                            .where(billable: owner, subscription: plan)
                            .where("created_at > ?", REUSE_WINDOW.ago)
                            .recent
                            .detect { |session| session.reusable? }
    end

    def create_stripe_session(owner, plan, price_id, customer)
      metadata = {
        "owner_type" => owner.class.name,
        "owner_id" => owner.id.to_s,
        "plan_id" => plan.id.to_s,
        "plan_slug" => plan.slug
      }

      StripeGateway.create_checkout_session(
        mode: "subscription",
        customer: customer.stripe_customer_id,
        client_reference_id: "#{owner.class.name}:#{owner.id}",
        line_items: [ { price: price_id, quantity: 1 } ],
        success_url: Configuration.success_url,
        cancel_url: Configuration.cancel_url,
        allow_promotion_codes: false,
        metadata: metadata,
        subscription_data: { metadata: metadata }
      )
    end

    def persist_checkout(owner, plan, customer, session)
      BillingCheckoutSession.create!(
        billable: owner,
        subscription: plan,
        stripe_checkout_session_id: session.id,
        stripe_customer_id: customer.stripe_customer_id,
        status: session.status.to_s.presence_in(%w[open completed expired]) || "open",
        url: session.url,
        expires_at: session.expires_at.present? ? Time.zone.at(session.expires_at) : REUSE_WINDOW.from_now,
        metadata: {
          "client_reference_id" => "#{owner.class.name}:#{owner.id}",
          "plan_slug" => plan.slug
        }
      )
    rescue ActiveRecord::RecordNotUnique
      BillingCheckoutSession.find_by!(stripe_checkout_session_id: session.id)
    end
  end
end
