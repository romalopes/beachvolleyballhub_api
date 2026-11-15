require "test_helper"

# Entitlement resolution is the only place subscription state is interpreted.
# These tests pin the status policy: free fallback, paid statuses, grace, period
# end, retired plans and personal/organisation isolation.
class Entitlements::ResolverTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:three)          # user three: coach, not an admin
    @organisation = organisations(:sydney_club)
  end

  test "an owner with no billing record falls back to FREE" do
    resolver = Entitlements::Resolver.new(@account)

    assert_predicate resolver, :free_fallback?
    refute_predicate resolver, :entitled?
    assert_equal subscriptions(:free), resolver.plan
    assert_equal "free", resolver.status
    assert_equal [], resolver.effective_feature_slugs
    refute resolver.feature_enabled?("enhanced_player_profile")
  end

  test "an active paid subscription grants exactly its catalogue features" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:coach))
    resolver = Entitlements::Resolver.new(@account)

    assert_predicate resolver, :entitled?
    refute_predicate resolver, :free_fallback?
    assert_equal "active", resolver.status
    assert resolver.feature_enabled?("advanced_training_planning")
    assert resolver.feature_enabled?("advanced_assessments")
    refute resolver.feature_enabled?("club_reporting")
    assert_equal 0, resolver.limit_for(:included_users)
  end

  test "past_due keeps access only inside the grace window" do
    record = create_billing_subscription!(
      owner: @account, plan: subscriptions(:coach), status: "past_due",
      grace_period_ends_at: 2.days.from_now
    )
    assert Entitlements::Resolver.new(@account).entitled?

    record.update!(grace_period_ends_at: 1.day.ago)
    refute Entitlements::Resolver.new(@account).entitled?
    assert_equal subscriptions(:free), Entitlements::Resolver.new(@account).plan
  end

  test "cancel_at_period_end keeps access until the period really ends" do
    record = create_billing_subscription!(
      owner: @account, plan: subscriptions(:player), cancel_at_period_end: true,
      current_period_end: 10.days.from_now
    )
    assert Entitlements::Resolver.new(@account).entitled?

    record.update!(current_period_end: 1.day.ago)
    refute Entitlements::Resolver.new(@account).entitled?
  end

  test "canceled and unpaid subscriptions grant no paid access" do
    record = create_billing_subscription!(owner: @account, plan: subscriptions(:coach))
    %w[canceled unpaid incomplete incomplete_expired paused].each do |status|
      record.update!(status: status)
      resolver = Entitlements::Resolver.new(@account)
      refute resolver.entitled?, "expected #{status} to be unentitled"
      assert_equal subscriptions(:free), resolver.plan
    end
  end

  test "a retired plan cannot keep granting its old features" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:retired))
    resolver = Entitlements::Resolver.new(@account)

    assert_predicate resolver, :free_fallback?
    refute resolver.feature_enabled?("advanced_training_planning")
  end

  test "personal and organisation entitlements are independent" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:coach))
    create_billing_subscription!(owner: @organisation, plan: subscriptions(:club))

    personal = Entitlements::Resolver.new(@account)
    club = Entitlements::Resolver.new(@organisation)

    assert personal.feature_enabled?("advanced_training_planning")
    refute personal.feature_enabled?("club_reporting")

    assert club.feature_enabled?("club_reporting")
    assert club.feature_enabled?("organisation_management")
    assert_equal 5, club.effective_features.size
  end

  test "each organisation resolves its own subscription" do
    create_billing_subscription!(owner: @organisation, plan: subscriptions(:club))
    other = organisations(:northern_club)

    assert Entitlements::Resolver.new(@organisation).entitled?
    refute Entitlements::Resolver.new(other).entitled?
    assert_equal subscriptions(:free), Entitlements::Resolver.new(other).plan
  end

  test "a User is resolved through its personal account" do
    create_billing_subscription!(owner: @account, plan: subscriptions(:player))
    resolver = Entitlements::Resolver.new(users(:three))

    assert resolver.feature_enabled?("enhanced_player_profile")
    assert_equal @account.id, resolver.owner.id
  end

  test "nil and zero limits have different, explicit meanings" do
    assert Entitlements::Quota.unlimited?(nil)
    refute Entitlements::Quota.exceeded?(limit: nil, usage: 10_000)

    assert Entitlements::Quota.exceeded?(limit: 0, usage: 0)
    refute Entitlements::Quota.exceeded?(limit: 3, usage: 2)
    assert Entitlements::Quota.exceeded?(limit: 3, usage: 3)
    assert_equal 0, Entitlements::Quota.remaining(limit: 3, usage: 5)
    assert_nil Entitlements::Quota.remaining(limit: nil, usage: 5)
  end

  test "organisation seat usage counts active memberships only" do
    usage = Entitlements::Usage.value_for(@organisation, :included_users)

    assert_equal @organisation.organisation_memberships.active.count, usage
    assert_nil Entitlements::Usage.value_for(@account, :included_users)
  end

  test "the suggested plan is the cheapest plan granting a feature" do
    resolver = Entitlements::Resolver.new(@account)

    assert_equal subscriptions(:player), resolver.suggested_plan_for("enhanced_player_profile")
    assert_equal subscriptions(:coach), resolver.suggested_plan_for("advanced_training_planning")
    assert_equal subscriptions(:club), resolver.suggested_plan_for("club_reporting")
    assert_nil resolver.suggested_plan_for("no_such_feature")
  end
end
