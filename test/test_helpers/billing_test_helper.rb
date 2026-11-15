module BillingTestHelper
  # Replaces one singleton method for the duration of the block.
  #
  # Minitest 6 no longer ships `minitest/mock`, so the test suite stubs the one
  # seam it needs — `Billing::StripeGateway` — directly. The original method object
  # is restored in `ensure`, so a failing assertion cannot leak a stub into the
  # next test.
  def stub_singleton_method(mod, name, value_or_callable)
    original = mod.method(name)
    mod.singleton_class.send(:define_method, name) do |*args, **kwargs, &block|
      if value_or_callable.respond_to?(:call)
        value_or_callable.call(*args, **kwargs, &block)
      else
        value_or_callable
      end
    end
    yield
  ensure
    mod.singleton_class.send(:remove_method, name)
    mod.singleton_class.send(:define_method, name, original)
  end

  # Creates a local subscription record without touching Stripe. Tests that
  # exercise entitlement or reporting need exactly this: a record that looks like
  # a confirmed webhook wrote it.
  def create_billing_subscription!(owner:, plan:, status: "active", **attributes)
    BillingSubscription.create!({
      billable: owner,
      subscription: plan,
      status: status,
      stripe_customer_id: "cus_test_#{SecureRandom.hex(6)}",
      stripe_subscription_id: "sub_test_#{SecureRandom.hex(6)}",
      stripe_price_id: Billing::PriceCatalog.price_id_for(plan),
      current_period_start: 1.month.ago,
      current_period_end: 11.months.from_now,
      last_synced_at: Time.current
    }.merge(attributes))
  end

  def create_billing_customer!(owner:, stripe_customer_id: nil)
    BillingCustomer.create!(
      billable: owner,
      stripe_customer_id: stripe_customer_id || "cus_test_#{SecureRandom.hex(6)}",
      email: "billing-#{SecureRandom.hex(4)}@example.com"
    )
  end

  # Builds a Stripe-shaped event hash. The processor works on plain hashes, which
  # is also what the controller passes after signature verification.
  def stripe_event(type:, object:, id: nil, created: Time.current.to_i)
    {
      "id" => id || "evt_test_#{SecureRandom.hex(8)}",
      "type" => type,
      "created" => created,
      "data" => { "object" => object.deep_stringify_keys }
    }.deep_stringify_keys
  end

  def stripe_subscription_object(plan:, customer_id:, subscription_id: nil, status: "active", **overrides)
    {
      "id" => subscription_id || "sub_test_#{SecureRandom.hex(6)}",
      "object" => "subscription",
      "customer" => customer_id,
      "status" => status,
      "current_period_start" => 1.month.ago.to_i,
      "current_period_end" => 11.months.from_now.to_i,
      "cancel_at_period_end" => false,
      "canceled_at" => nil,
      "ended_at" => nil,
      "metadata" => {},
      "items" => {
        "data" => [
          { "id" => "si_test_1", "price" => { "id" => Billing::PriceCatalog.price_id_for(plan) } }
        ]
      }
    }.deep_merge(overrides.deep_stringify_keys)
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include BillingTestHelper
end
