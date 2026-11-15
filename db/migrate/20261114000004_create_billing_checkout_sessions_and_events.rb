# Checkout correlation and webhook idempotency (IDENTITY-116, Phase 1/5).
#
# `billing_checkout_sessions` records the Checkout Session the API created, so a
# `checkout.session.completed` webhook can be correlated back to the internal
# owner and plan without trusting browser query parameters. It also lets the API
# return an existing open session instead of creating a duplicate one.
#
# `billing_events` is the webhook idempotency ledger. `stripe_event_id` is unique,
# so Stripe's at-least-once delivery can never apply the same event twice, and the
# stored status makes failed processing visible to administrators.
class CreateBillingCheckoutSessionsAndEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_checkout_sessions do |t|
      t.string :billable_type, null: false
      t.bigint :billable_id, null: false
      t.references :subscription, null: false, foreign_key: true
      t.string :stripe_checkout_session_id, null: false
      t.string :stripe_customer_id
      t.string :status, null: false, default: "open"
      t.text :url
      t.datetime :expires_at
      t.datetime :completed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :billing_checkout_sessions, :stripe_checkout_session_id, unique: true
    add_index :billing_checkout_sessions, [ :billable_type, :billable_id, :created_at ],
              name: "index_billing_checkout_sessions_on_owner_and_time"
    add_check_constraint :billing_checkout_sessions,
                         "billable_type IN ('Account', 'Organisation')",
                         name: "billing_checkout_sessions_billable_type"
    add_check_constraint :billing_checkout_sessions,
                         "status IN ('open', 'completed', 'expired', 'canceled')",
                         name: "billing_checkout_sessions_status"

    create_table :billing_events do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.string :stripe_object_id
      t.string :status, null: false, default: "received"
      t.integer :attempts, null: false, default: 0
      t.text :error_message
      t.datetime :stripe_created_at
      t.datetime :received_at
      t.datetime :processed_at
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :billing_events, :stripe_event_id, unique: true
    add_index :billing_events, [ :event_type, :created_at ]
    add_index :billing_events, :status
    add_check_constraint :billing_events,
                         "status IN ('received', 'processed', 'failed', 'skipped')",
                         name: "billing_events_status"
  end
end
