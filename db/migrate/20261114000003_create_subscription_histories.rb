# Append-only subscription lifecycle history (IDENTITY-116, Phase 1).
#
# Every meaningful transition is recorded here — checkout activation, renewal,
# plan change, cancellation, admin assignment — with the plan that was replaced,
# the source of the change and the Stripe identifiers in play. Rows are only
# inserted, never updated, so "what was this account entitled to in March?" has
# an answer even after the catalogue changes.
class CreateSubscriptionHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_histories do |t|
      t.string :billable_type, null: false
      t.bigint :billable_id, null: false
      t.references :subscription, null: false, foreign_key: true
      t.bigint :previous_subscription_id
      t.string :status, null: false
      t.string :source, null: false
      t.string :stripe_subscription_id
      t.string :stripe_price_id
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :canceled_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :subscription_histories, [ :billable_type, :billable_id, :created_at ],
              name: "index_subscription_histories_on_owner_and_time"
    add_foreign_key :subscription_histories, :subscriptions,
                    column: :previous_subscription_id
    add_check_constraint :subscription_histories,
                         "billable_type IN ('Account', 'Organisation')",
                         name: "subscription_histories_billable_type"
  end
end
