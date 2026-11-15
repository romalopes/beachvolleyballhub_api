require "test_helper"

# Catalogue invariants (IDENTITY-116, Phase 1/2): one default plan, integer-cent
# annual prices, owner compatibility and safe retirement.
class SubscriptionTest < ActiveSupport::TestCase
  test "the default plan is the free plan" do
    assert_equal subscriptions(:free), Subscription.default_plan
    assert_predicate subscriptions(:free), :default?
    assert_predicate subscriptions(:free), :free?
    assert_equal 0, subscriptions(:free).yearly_price_cents
    assert_equal "AUD", subscriptions(:free).currency
  end

  test "paid plans carry integer-cent annual prices" do
    assert_equal 500, subscriptions(:player).yearly_price_cents
    assert_equal 1000, subscriptions(:coach).yearly_price_cents
    assert_equal 5000, subscriptions(:club).yearly_price_cents
    [ :player, :coach, :club ].each do |name|
      assert_predicate subscriptions(name), :purchasable?
      refute_predicate subscriptions(name), :default?
    end
  end

  test "free is not purchasable because it is assigned rather than bought" do
    refute_predicate subscriptions(:free), :purchasable?
    refute_predicate subscriptions(:retired), :purchasable?
  end

  test "only one active default plan is allowed" do
    second_default = Subscription.new(
      name: "Another default", slug: "another-default", currency: "AUD",
      yearly_price_cents: 0, is_default: true, owner_scope: "both"
    )

    refute second_default.valid?
    assert_includes second_default.errors[:is_default], "is already taken by another active plan"
  end

  test "the default plan must be free" do
    plan = Subscription.new(
      name: "Paid default", slug: "paid-default", currency: "AUD",
      yearly_price_cents: 500, is_default: true, owner_scope: "personal"
    )

    refute plan.valid?
    assert_includes plan.errors[:yearly_price_cents], "must be zero for the default plan"
  end

  test "negative prices and unknown owner scopes are rejected" do
    plan = Subscription.new(
      name: "Bad", slug: "bad-plan", currency: "AUD",
      yearly_price_cents: -1, owner_scope: "everyone"
    )

    refute plan.valid?
    assert_includes plan.errors[:yearly_price_cents], "must be greater than or equal to 0"
    assert_includes plan.errors[:owner_scope], "is not included in the list"
  end

  test "owner scope decides which owner may buy a plan" do
    assert subscriptions(:player).supports_owner?("Account")
    refute subscriptions(:player).supports_owner?("Organisation")

    assert subscriptions(:club).supports_owner?("Organisation")
    refute subscriptions(:club).supports_owner?("Account")

    assert subscriptions(:free).supports_owner?("Account")
    assert subscriptions(:free).supports_owner?("Organisation")
  end

  test "the approved feature counts per plan are preserved" do
    assert_equal [ "enhanced_player_profile" ], subscriptions(:player).feature_slugs
    assert_equal 3, subscriptions(:coach).feature_slugs.size
    assert_equal 5, subscriptions(:club).feature_slugs.size
    assert_equal [], subscriptions(:free).feature_slugs
  end

  test "a plan with billing history cannot be destroyed" do
    plan = subscriptions(:player)
    create_billing_subscription!(owner: accounts(:three), plan: plan)

    refute plan.destroy
    assert plan.errors.any?
    assert Subscription.exists?(plan.id)
  end
end
