require "test_helper"

# Checkout creation (IDENTITY-116, Phase 4). Stripe is stubbed at the gateway seam,
# so these tests assert exactly what the API would send: the server-resolved Price,
# subscription mode, trusted return URLs and correlation metadata.
class Billing::CheckoutServiceTest < ActiveSupport::TestCase
  FakePrice = Struct.new(:currency, :recurring)
  FakeRecurring = Struct.new(:interval)
  FakeCustomer = Struct.new(:id)
  FakeSession = Struct.new(:id, :url, :status, :expires_at)

  setup do
    @previous_secret = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_checkout_service"
    @account = accounts(:three)
    @user = users(:three)
    @session = FakeSession.new("cs_test_123", "https://checkout.stripe.test/cs_test_123", "open",
                               1.hour.from_now.to_i)
  end

  teardown do
    ENV["STRIPE_SECRET_KEY"] = @previous_secret
  end

  test "creates a subscription-mode session with the configured Price" do
    captured = nil
    result = with_stripe(create_checkout: ->(params) { captured = params; @session }) do
      Billing::CheckoutService.new(user: @user, plan_slug: "player").call
    end

    assert_equal "https://checkout.stripe.test/cs_test_123", result.url
    refute result.reused

    assert_equal "subscription", captured[:mode]
    assert_equal "price_player_test", captured[:line_items].first[:price]
    assert_equal 1, captured[:line_items].first[:quantity]
    assert_includes captured[:success_url], "CHECKOUT_SESSION_ID"
    assert_equal "Account", captured[:metadata]["owner_type"]
    assert_equal @account.id.to_s, captured[:metadata]["owner_id"]
    assert_equal "player", captured[:subscription_data][:metadata]["plan_slug"]

    checkout = BillingCheckoutSession.last
    assert_equal @account, checkout.billable
    assert_equal subscriptions(:player), checkout.subscription
    assert_equal @session.id, checkout.stripe_checkout_session_id
  end

  test "returns the open session instead of creating a duplicate" do
    calls = 0
    counter = ->(_params) { calls += 1; @session }

    with_stripe(create_checkout: counter) do
      first = Billing::CheckoutService.new(user: @user, plan_slug: "player").call
      second = Billing::CheckoutService.new(user: @user, plan_slug: "player").call

      refute first.reused
      assert second.reused
      assert_equal first.session_id, second.session_id
    end
    assert_equal 1, calls
  end

  test "rejects a second paid subscription for the same owner" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:player))

    error = assert_raises(Billing::Errors::AlreadySubscribed) do
      Billing::CheckoutService.new(user: @user, plan_slug: "coach").call
    end
    assert_equal "subscription_already_active", error.code
  end

  test "rejects a plan the owner type cannot buy" do
    assert_raises(Billing::Errors::PlanIncompatible) do
      Billing::CheckoutService.new(user: @user, plan_slug: "club").call
    end
  end

  test "rejects a plan that is not purchasable" do
    assert_raises(Billing::Errors::PlanNotPurchasable) do
      Billing::CheckoutService.new(user: @user, plan_slug: "free").call
    end

    assert_raises(Billing::Errors::PlanNotPurchasable) do
      Billing::CheckoutService.new(user: @user, plan_slug: "no_such_plan").call
    end
  end

  test "a member who does not manage the club cannot buy its subscription" do
    assert_raises(Billing::Errors::OwnerNotEligible) do
      Billing::CheckoutService.new(
        user: users(:five), plan_slug: "club",
        owner_type: "organisation", owner_id: organisations(:sydney_club).id
      ).call
    end
  end

  test "an organisation owner can buy the Club plan for the club" do
    captured = nil
    owner = users(:six) # owner of sydney_club in the fixtures

    with_stripe(create_checkout: ->(params) { captured = params; @session }) do
      Billing::CheckoutService.new(
        user: owner, plan_slug: "club",
        owner_type: "organisation", owner_id: organisations(:sydney_club).id
      ).call
    end

    assert_equal "Organisation", captured[:metadata]["owner_type"]
    assert_equal organisations(:sydney_club).id.to_s, captured[:metadata]["owner_id"]
    assert_equal "price_club_test", captured[:line_items].first[:price]
    assert_equal organisations(:sydney_club), BillingCheckoutSession.last.billable
  end

  private

  def with_stripe(create_checkout:)
    price = FakePrice.new("aud", FakeRecurring.new("year"))
    stub_singleton_method(Billing::StripeGateway, :retrieve_price, price) do
      stub_singleton_method(Billing::StripeGateway, :create_customer,
                            FakeCustomer.new("cus_checkout_test")) do
        stub_singleton_method(Billing::StripeGateway, :create_checkout_session, create_checkout) { yield }
      end
    end
  end
end
