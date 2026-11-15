# Billing ownership, current state and history (IDENTITY-116, Phase 1).
#
# The billable owner is polymorphic on purpose, restricted by check constraint
# to the only two owner kinds this product supports:
#   * Account      — a personal Player/Coach subscription
#   * Organisation — a Club subscription owned by the club, not by whoever
#                    happens to click Checkout
#
# One current billing record per owner is enforced by a unique index. History is
# a separate append-only table, which is why replacing a plan never destroys the
# previous one. Stripe identifiers are persisted only for reconciliation; card
# data is never stored.
class CreateBillingRecords < ActiveRecord::Migration[8.1]
  OWNER_TYPES = "'Account', 'Organisation'".freeze
  STATUSES = "'incomplete', 'incomplete_expired', 'trialing', 'active', " \
             "'past_due', 'canceled', 'unpaid', 'paused'".freeze

  def change
    create_table :billing_customers do |t|
      t.string :billable_type, null: false
      t.bigint :billable_id, null: false
      t.string :stripe_customer_id, null: false
      t.string :email
      t.timestamps
    end

    add_index :billing_customers, [ :billable_type, :billable_id ], unique: true,
              name: "index_billing_customers_on_owner"
    add_index :billing_customers, :stripe_customer_id, unique: true
    add_check_constraint :billing_customers,
                         "billable_type IN (#{OWNER_TYPES})",
                         name: "billing_customers_billable_type"

    create_table :billing_subscriptions do |t|
      t.string :billable_type, null: false
      t.bigint :billable_id, null: false
      t.references :subscription, null: false, foreign_key: true
      t.string :status, null: false, default: "incomplete"
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.string :stripe_price_id
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.boolean :cancel_at_period_end, null: false, default: false
      t.datetime :canceled_at
      t.datetime :ended_at
      t.datetime :trial_ends_at
      # Failed-payment grace window, set from invoice.payment_failed and cleared
      # by the next successful payment.
      t.datetime :grace_period_ends_at
      # A requested change that Stripe has not confirmed yet. The local
      # `subscription_id` stays on the *current* plan until the webhook reports
      # the new Price.
      t.bigint :pending_subscription_id
      t.datetime :pending_change_requested_at
      t.datetime :pending_change_effective_at
      t.datetime :last_synced_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :billing_subscriptions, [ :billable_type, :billable_id ], unique: true,
              name: "index_billing_subscriptions_on_owner"
    add_index :billing_subscriptions, :stripe_subscription_id, unique: true
    add_index :billing_subscriptions, :status
    add_index :billing_subscriptions, :pending_subscription_id
    add_foreign_key :billing_subscriptions, :subscriptions,
                    column: :pending_subscription_id
    add_check_constraint :billing_subscriptions,
                         "billable_type IN (#{OWNER_TYPES})",
                         name: "billing_subscriptions_billable_type"
    add_check_constraint :billing_subscriptions,
                         "status IN (#{STATUSES})",
                         name: "billing_subscriptions_status"
  end
end
