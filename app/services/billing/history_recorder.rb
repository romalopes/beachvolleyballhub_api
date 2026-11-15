module Billing
  # Writes the append-only lifecycle history (IDENTITY-116).
  #
  # Callers pass what happened and where the information came from; this service
  # normalises the Stripe identifiers and timestamps so every row is comparable.
  # It never updates an existing row.
  class HistoryRecorder
    class << self
      def record!(billable:, plan:, status:, source:,
                  previous_plan: nil, stripe_subscription_id: nil,
                  stripe_price_id: nil, started_at: nil, ended_at: nil,
                  canceled_at: nil, metadata: {})
        SubscriptionHistory.create!(
          billable: billable,
          subscription: plan,
          previous_subscription: previous_plan,
          status: status,
          source: source,
          stripe_subscription_id: stripe_subscription_id,
          stripe_price_id: stripe_price_id,
          started_at: started_at,
          ended_at: ended_at,
          canceled_at: canceled_at,
          metadata: metadata
        )
      end

      # A plan or lifecycle status changed enough to be worth a history row.
      def record_transition!(billing_subscription, previous_plan:, source:, status: nil, metadata: {})
        record!(
          billable: billing_subscription.billable,
          plan: billing_subscription.subscription,
          previous_plan: previous_plan,
          status: status || billing_subscription.status,
          source: source,
          stripe_subscription_id: billing_subscription.stripe_subscription_id,
          stripe_price_id: billing_subscription.stripe_price_id,
          started_at: billing_subscription.current_period_start,
          ended_at: billing_subscription.ended_at,
          canceled_at: billing_subscription.canceled_at,
          metadata: metadata
        )
      end
    end
  end
end
