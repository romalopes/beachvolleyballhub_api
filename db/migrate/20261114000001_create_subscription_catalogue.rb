# Subscription catalogue (IDENTITY-116, Phase 1).
#
# Three tables, deliberately separate:
#   * subscriptions                  — the sellable plans (FREE, Player, Coach, Club)
#   * subscription_features          — an independent capability catalogue, so a
#                                      feature can be re-used across plans and
#                                      renamed without touching plan rows
#   * subscription_subscription_features — ordered plan → feature associations
#
# Money is stored as integer cents with an ISO-4217 currency: never a float, and
# never an amount the browser supplied. `yearly_price_cents` is the catalogue
# price used for display, comparisons and admin editing. The Stripe Price actually
# charged is resolved server-side from trusted configuration
# (see Billing::PriceCatalog); the optional `stripe_price_id` column is only a
# fallback for plans created through the admin UI.
#
# Limit semantics (Phase 0 decision, encoded in the resolver):
#   * NULL  — unlimited / not applicable
#   * 0     — none beyond the documented owner access
#   * n > 0 — explicit quota
#
# `owner_scope` records which kind of billable owner may buy a plan: personal
# (Account), organisation (Organisation) or both (the FREE fallback).
class CreateSubscriptionCatalogue < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.boolean :visible, null: false, default: true
      t.boolean :popular, null: false, default: false
      t.boolean :is_default, null: false, default: false
      t.integer :position, null: false, default: 0
      t.string :currency, null: false, default: "AUD"
      t.integer :yearly_price_cents, null: false, default: 0
      t.string :owner_scope, null: false, default: "personal"
      t.integer :included_users
      t.integer :history_limit
      t.string :stripe_price_id
      t.timestamps
    end

    add_index :subscriptions, :slug, unique: true
    # Exactly one default plan may exist. The partial unique index is the real
    # guard: a model validation loses a race, this cannot.
    add_index :subscriptions, :is_default, unique: true, where: "is_default",
              name: "index_subscriptions_single_default"
    add_index :subscriptions, [ :active, :visible, :position ]

    add_check_constraint :subscriptions, "yearly_price_cents >= 0",
                         name: "subscriptions_price_non_negative"
    add_check_constraint :subscriptions, "char_length(currency) = 3",
                         name: "subscriptions_currency_iso4217"
    add_check_constraint :subscriptions,
                         "owner_scope IN ('personal', 'organisation', 'both')",
                         name: "subscriptions_owner_scope"
    add_check_constraint :subscriptions, "included_users IS NULL OR included_users >= 0",
                         name: "subscriptions_included_users_non_negative"
    add_check_constraint :subscriptions, "history_limit IS NULL OR history_limit >= 0",
                         name: "subscriptions_history_limit_non_negative"

    create_table :subscription_features do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :subscription_features, :slug, unique: true
    add_index :subscription_features, [ :active, :position ]

    create_table :subscription_subscription_features do |t|
      t.references :subscription, null: false, foreign_key: { on_delete: :cascade }
      t.references :subscription_feature, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :subscription_subscription_features,
              [ :subscription_id, :subscription_feature_id ],
              unique: true,
              name: "index_subscription_features_unique_pair"
    add_index :subscription_subscription_features,
              [ :subscription_id, :position ],
              name: "index_subscription_features_on_plan_and_position"
  end
end
