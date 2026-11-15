# Phase 1 — Subscription data model

**Status:** complete

## Objective

Create the catalogue, owner state, Stripe mapping and append-only history needed
for both personal and organisation billing.

## Migrations

| File | Tables |
|---|---|
| `db/migrate/20261114000001_create_subscription_catalogue.rb` | `subscriptions`, `subscription_features`, `subscription_subscription_features` |
| `db/migrate/20261114000002_create_billing_records.rb` | `billing_customers`, `billing_subscriptions` |
| `db/migrate/20261114000003_create_subscription_histories.rb` | `subscription_histories` |
| `db/migrate/20261114000004_create_billing_checkout_sessions_and_events.rb` | `billing_checkout_sessions`, `billing_events` |

## Models

- `app/models/subscription.rb` — plan catalogue. Unique slug, partial unique index
  for one default, price/currency/scope check constraints, `purchasable?`,
  `supports_owner?`, `feature_slugs`, delete guard.
- `app/models/subscription_feature.rb` — capability catalogue keyed by `slug`.
- `app/models/subscription_subscription_feature.rb` — ordered join.
- `app/models/billing_customer.rb` — one Stripe Customer per owner.
- `app/models/billing_subscription.rb` — one current record per owner, Stripe
  statuses verbatim, grace/pending-change helpers.
- `app/models/subscription_history.rb` — append-only (`readonly?` once persisted).
- `app/models/billing_checkout_session.rb` — session correlation and reuse window.
- `app/models/billing_event.rb` — webhook idempotency ledger.

Associations added to `Account` and `Organisation` with
`dependent: :restrict_with_error`, so billing history is never cascaded.

## Database guarantees

- `subscriptions.is_default` partial unique index — one default plan.
- `yearly_price_cents >= 0`, three-letter currency, known `owner_scope`, non-negative
  limits.
- `billing_customers` unique owner pair and unique `stripe_customer_id`.
- `billing_subscriptions` unique owner pair, unique `stripe_subscription_id`,
  status check constraint.
- `billing_events.stripe_event_id` unique.
- Owner type check constraints on every polymorphic billing table
  (`Account`, `Organisation`).
- Foreign keys with the project's existing delete semantics.

## Deliberate choices

- No card data, ever.
- No `users.subscription_id`: an organisation is not a user.
- `metadata jsonb` for safe extensibility (last applied event timestamp, admin
  assignment reason), never for secrets.
- History is a separate table so replacing a plan does not overwrite the record of
  what came before.

## Verification

```bash
bin/rails db:migrate
bin/rails db:rollback STEP=4
bin/rails db:migrate
bin/rails zeitwerk:check
bin/rails test test/models/subscription_test.rb
```

All four migrations applied and rolled back cleanly. `db/schema.rb` updated.
