require "test_helper"

# Plan changes (IDENTITY-116, Phase 6). The central assertion is that local
# entitlement is never changed optimistically: the plan stays as it was until the
# webhook confirms Stripe's new state.
class Billing::PlanChangeServiceTest < ActiveSupport::TestCase
  # Captures the params passed to a stubbed gateway call. A recorder object (rather
  # than a lambda) keeps the assertion independent of how Minitest forwards keyword
  # arguments.
  class Recorder
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(*args, **kwargs)
      @calls << (kwargs.present? ? kwargs : args.last)
      nil
    end

    def params
      calls.last
    end
  end

  setup do
    @previous_secret = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_plan_change"
    @account = accounts(:three)
    @user = users(:three)
    @record = create_billing_subscription!(
      owner: @account, plan: subscriptions(:player),
      stripe_subscription_id: "sub_change_test",
      current_period_end: 6.months.from_now
    )
  end

  teardown do
    ENV["STRIPE_SECRET_KEY"] = @previous_secret
  end

  test "an upgrade asks Stripe for immediate proration and stays pending locally" do
    recorder = Recorder.new
    result = stub_singleton_method(Billing::StripeGateway, :current_item_id, "si_change_test") do
      stub_singleton_method(Billing::StripeGateway, :update_subscription, recorder) do
        change(plan_slug: "coach")
      end
    end

    assert_equal "pending_confirmation", result[:status]
    assert_equal "upgrade", result[:action]
    assert_equal "always_invoice", recorder.params[:proration_behavior]
    assert_equal "price_coach_test", recorder.params[:items].first[:price]

    @record.reload
    assert_equal subscriptions(:player), @record.subscription, "current plan must not change before confirmation"
    assert_equal subscriptions(:coach), @record.pending_subscription
    assert_predicate @record, :pending_change?
  end

  test "a downgrade is scheduled for renewal, not applied now" do
    @record.update!(subscription: subscriptions(:coach))
    recorder = Recorder.new

    result = stub_singleton_method(Billing::StripeGateway, :schedule_plan_change, recorder) do
      change(plan_slug: "player")
    end

    assert_equal "downgrade", result[:action]
    assert_equal "price_player_test", recorder.params[:new_price_id]
    assert_equal "sub_change_test", recorder.params[:subscription_id]

    @record.reload
    assert_equal subscriptions(:coach), @record.subscription
    assert_equal @record.current_period_end, @record.pending_change_effective_at
  end

  test "cancellation is requested at period end" do
    recorder = Recorder.new
    result = stub_singleton_method(Billing::StripeGateway, :update_subscription, recorder) do
      change(action: "cancel")
    end

    assert_equal "cancellation_requested", result[:status]
    assert_equal true, recorder.params[:cancel_at_period_end]
    assert @record.reload.metadata["cancel_requested_at"].present?
  end

  test "a pending cancellation can be reversed" do
    @record.update!(cancel_at_period_end: true)
    recorder = Recorder.new
    result = stub_singleton_method(Billing::StripeGateway, :update_subscription, recorder) do
      change(action: "resume")
    end

    assert_equal "cancellation_reversed", result[:status]
    assert_equal false, recorder.params[:cancel_at_period_end]
  end

  test "resuming a subscription that is not cancelling is refused" do
    assert_raises(Billing::Errors::BillingError) { change(action: "resume") }
  end

  test "the same plan is refused" do
    assert_raises(Billing::Errors::SamePlan) { change(plan_slug: "player") }
  end

  test "a member without club billing permission cannot change the club plan" do
    create_billing_subscription!(owner: organisations(:sydney_club), plan: subscriptions(:club))

    assert_raises(Billing::Errors::OwnerNotEligible) do
      Billing::PlanChangeService.new(
        user: users(:five), plan_slug: "club",
        owner_type: "organisation", owner_id: organisations(:sydney_club).id
      ).call
    end
  end

  test "a subscription without a Stripe id cannot be changed" do
    @record.update!(stripe_subscription_id: nil)

    assert_raises(Billing::Errors::NoActiveSubscription) { change(plan_slug: "coach") }
  end

  private

  def change(plan_slug: nil, action: "change")
    Billing::PlanChangeService.new(user: @user, plan_slug: plan_slug, action: action).call
  end
end
