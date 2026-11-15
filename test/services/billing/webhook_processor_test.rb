require "test_helper"

# Webhook behaviour (IDENTITY-116, Phase 5): correlation, idempotency, ordering,
# renewal, failed payment and cancellation. Stripe is represented by event hashes,
# which is exactly what the controller passes after signature verification.
class Billing::WebhookProcessorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:three)
    @customer = create_billing_customer!(owner: @account)
  end

  test "customer.subscription.created activates a paid plan and writes history" do
    object = stripe_subscription_object(plan: subscriptions(:coach), customer_id: @customer.stripe_customer_id)

    assert_equal :processed, process(stripe_event(type: "customer.subscription.created", object: object))

    record = @account.reload.billing_subscription
    assert_equal subscriptions(:coach), record.subscription
    assert_equal "active", record.status
    assert_equal object["id"], record.stripe_subscription_id
    assert_equal "active", SubscriptionHistory.for_owner(@account).last.status
    assert BillingEvent.last.processed?
  end

  test "duplicate delivery is skipped and never applied twice" do
    object = stripe_subscription_object(plan: subscriptions(:player), customer_id: @customer.stripe_customer_id)
    event = stripe_event(type: "customer.subscription.created", object: object)

    assert_equal :processed, Billing::WebhookProcessor.new(event).call
    assert_equal :duplicate, Billing::WebhookProcessor.new(event).call

    assert_equal 1, BillingEvent.where(stripe_event_id: event["id"]).count
    assert_equal 1, @account.reload.subscription_histories.count
  end

  test "an older event cannot revert newer state" do
    newer = stripe_subscription_object(
      plan: subscriptions(:coach), customer_id: @customer.stripe_customer_id,
      subscription_id: "sub_order_test"
    )
    process(stripe_event(type: "customer.subscription.created", object: newer, created: 2.hours.ago.to_i))

    stale = newer.deep_merge("status" => "canceled", "ended_at" => 1.hour.ago.to_i)
    result = process(stripe_event(type: "customer.subscription.deleted", object: stale, created: 3.hours.ago.to_i))

    assert_equal :out_of_order, result
    assert_equal "active", @account.reload.billing_subscription.status
  end

  test "an unknown Stripe Price is rejected instead of guessed" do
    object = stripe_subscription_object(plan: subscriptions(:coach), customer_id: @customer.stripe_customer_id)
    object["items"]["data"].first["price"]["id"] = "price_not_in_catalogue"

    assert_equal :failed, process(stripe_event(type: "customer.subscription.created", object: object))
    assert_nil @account.reload.billing_subscription
    assert BillingEvent.last.failed?
    assert_match(/not in the plan catalogue/, BillingEvent.last.error_message)
  end

  test "metadata naming a different owner is rejected" do
    object = stripe_subscription_object(plan: subscriptions(:player), customer_id: @customer.stripe_customer_id)
    object["metadata"] = { "owner_type" => "Account", "owner_id" => accounts(:one).id.to_s }

    assert_equal :failed, process(stripe_event(type: "customer.subscription.created", object: object))
    assert_nil @account.reload.billing_subscription
    assert_match(/metadata owner/, BillingEvent.last.error_message)
  end

  test "an unknown customer cannot activate anything" do
    object = stripe_subscription_object(plan: subscriptions(:player), customer_id: "cus_does_not_exist")

    assert_equal :failed, process(stripe_event(type: "customer.subscription.created", object: object))
    assert BillingEvent.last.failed?
  end

  test "invoice.payment_failed starts the documented grace window" do
    record = create_billing_subscription!(owner: @account, plan: subscriptions(:coach))
    invoice = { "id" => "in_test_1", "subscription" => record.stripe_subscription_id, "attempt_count" => 1 }

    assert_equal :processed, process(stripe_event(type: "invoice.payment_failed", object: invoice))

    record.reload
    assert_equal "past_due", record.status
    assert record.grace_period_ends_at > Time.current
    assert Entitlements::Resolver.new(@account).entitled?
    assert_equal "payment_failed", @account.subscription_histories.last.status
  end

  test "invoice.paid clears the grace window and records a renewal" do
    record = create_billing_subscription!(
      owner: @account, plan: subscriptions(:coach), status: "past_due",
      grace_period_ends_at: 2.days.from_now, current_period_end: 1.day.from_now
    )
    invoice = {
      "id" => "in_test_2",
      "subscription" => record.stripe_subscription_id,
      "lines" => { "data" => [ { "period" => { "start" => 1.day.from_now.to_i,
                                               "end" => 1.year.from_now.to_i } } ] }
    }

    assert_equal :processed, process(stripe_event(type: "invoice.paid", object: invoice))

    record.reload
    assert_equal "active", record.status
    assert_nil record.grace_period_ends_at
    assert record.current_period_end > 11.months.from_now
    assert_equal "renewal", @account.subscription_histories.last.status
  end

  test "checkout.session.completed with an expanded subscription activates it" do
    checkout = BillingCheckoutSession.create!(
      billable: @account,
      subscription: subscriptions(:player),
      stripe_checkout_session_id: "cs_test_completed",
      stripe_customer_id: @customer.stripe_customer_id,
      status: "open",
      url: "https://checkout.stripe.test/session",
      expires_at: 1.hour.from_now
    )
    object = stripe_subscription_object(plan: subscriptions(:player), customer_id: @customer.stripe_customer_id)
    session = {
      "id" => checkout.stripe_checkout_session_id,
      "customer" => @customer.stripe_customer_id,
      "subscription" => object,
      "metadata" => { "owner_type" => "Account", "owner_id" => @account.id.to_s,
                      "plan_slug" => "player" }
    }

    assert_equal :processed, process(stripe_event(type: "checkout.session.completed", object: session))
    assert_predicate checkout.reload, :completed?
    assert_equal subscriptions(:player), @account.reload.billing_subscription.subscription
  end

  test "subscription.deleted records the cancellation" do
    object = stripe_subscription_object(plan: subscriptions(:coach), customer_id: @customer.stripe_customer_id)
    process(stripe_event(type: "customer.subscription.created", object: object))

    deleted = object.merge("status" => "canceled", "ended_at" => Time.current.to_i)
    assert_equal :processed, process(stripe_event(type: "customer.subscription.deleted", object: deleted))

    record = @account.reload.billing_subscription
    assert_equal "canceled", record.status
    assert record.ended_at.present?
    refute Entitlements::Resolver.new(@account).entitled?
  end

  test "an unhandled event type is recorded as skipped" do
    assert_equal :skipped, process(stripe_event(type: "customer.created", object: { "id" => "cus_x" }))
    assert BillingEvent.last.skipped?
  end

  private

  def process(event)
    Billing::WebhookProcessor.new(event).call
  end
end
