require "test_helper"

# Reconciliation (IDENTITY-116, Phase 5) is the safety net for a webhook that was
# never delivered. It repairs through the same processor as a live event and never
# deletes local billing history or silently revokes access.
class Billing::ReconciliationServiceTest < ActiveSupport::TestCase
  FakeList = Struct.new(:data)

  setup do
    @previous_secret = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_reconciliation"
    @account = accounts(:three)
    @customer = create_billing_customer!(owner: @account)
  end

  teardown do
    ENV["STRIPE_SECRET_KEY"] = @previous_secret
  end

  test "repairs a local record that drifted from Stripe" do
    record = create_billing_subscription!(
      owner: @account, plan: subscriptions(:player), status: "active",
      stripe_customer_id: @customer.stripe_customer_id,
      stripe_subscription_id: "sub_reconcile_drift"
    )
    stripe_object = stripe_subscription_object(
      plan: subscriptions(:player), customer_id: @customer.stripe_customer_id,
      subscription_id: record.stripe_subscription_id, status: "canceled",
      ended_at: Time.current.to_i
    )

    summary = reconcile_with(stripe_object)

    assert_equal 1, summary.checked
    assert_equal 1, summary.repaired
    assert_equal "canceled", record.reload.status
    refute Entitlements::Resolver.new(@account).entitled?
  end

  test "a missing Stripe subscription is reported and local access is not silently revoked" do
    record = create_billing_subscription!(
      owner: @account, plan: subscriptions(:player),
      stripe_customer_id: @customer.stripe_customer_id,
      stripe_subscription_id: "sub_reconcile_missing"
    )
    missing = ->(_id) { raise Stripe::InvalidRequestError.new("No such subscription", nil) }

    summary = stub_singleton_method(Billing::StripeGateway, :list_customer_subscriptions,
                                    FakeList.new([])) do
      stub_singleton_method(Billing::StripeGateway, :retrieve_subscription, missing) do
        Billing::ReconciliationService.new.call
      end
    end

    assert_equal 1, summary.missing_in_stripe
    assert_equal "active", record.reload.status, "access revocation needs a human decision"
  end

  test "an orphaned Stripe subscription is recreated locally" do
    stripe_object = stripe_subscription_object(
      plan: subscriptions(:coach), customer_id: @customer.stripe_customer_id,
      subscription_id: "sub_reconcile_orphan"
    )
    list = FakeList.new([ stripe_object ])

    summary = stub_singleton_method(Billing::StripeGateway, :list_customer_subscriptions, list) do
      Billing::ReconciliationService.new.call
    end

    assert_equal 1, summary.orphaned
    record = BillingSubscription.find_by(stripe_subscription_id: "sub_reconcile_orphan")
    assert_equal subscriptions(:coach), record.subscription
    assert_equal "active", record.status
  end

  private

  def reconcile_with(stripe_object)
    lookup = ->(_id) { stripe_object }
    stub_singleton_method(Billing::StripeGateway, :list_customer_subscriptions, FakeList.new([])) do
      stub_singleton_method(Billing::StripeGateway, :retrieve_subscription, lookup) do
        Billing::ReconciliationService.new.call
      end
    end
  end
end
