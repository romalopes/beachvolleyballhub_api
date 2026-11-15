# Admin guide

Everything here requires an admin session (`AdminAreaPolicy#access?`, based on the
real authenticated user even while impersonating).

## Where

- SPA: `/settings/subscriptions`
- API: `/api/v1/admin/subscriptions`, `/api/v1/admin/subscription_features`,
  `/api/v1/admin/billing/*`

## Plans

```http
GET    /api/v1/admin/subscriptions
POST   /api/v1/admin/subscriptions          { "subscription": { "name": "...", "slug": "...", ... } }
PATCH  /api/v1/admin/subscriptions/:id      { "subscription": { "yearly_price_cents": 500, ... } }
DELETE /api/v1/admin/subscriptions/:id
PUT    /api/v1/admin/subscriptions/:id/features  { "feature_ids": [3, 1, 2] }
```

Editable fields: `name`, `slug`, `description`, `active`, `visible`, `popular`,
`is_default`, `position`, `currency`, `yearly_price_cents`, `owner_scope`,
`included_users`, `history_limit`, `stripe_price_id` (fallback only; environment
wins).

Rules enforced by the model and database:

- exactly one default plan, and it must be free;
- prices are non-negative integer cents with a three-letter currency;
- `owner_scope` is `personal`, `organisation` or `both`;
- setting `is_default` on a plan clears the flag from the others in the same update.

### Deleting

`DELETE` deletes only an unreferenced plan. A plan with billing records or history
is **deactivated** (`active: false`, `visible: false`) and the response says
`deactivated: true`. This is what keeps old invoices explicable.

### Changing a price

The catalogue price is for display and upgrade/downgrade comparison. Existing
subscribers keep the Stripe Price they agreed to. To move them, create a new Stripe
Price, point the environment variable at it, and change each subscription
explicitly (or run a documented migration). Do not expect a catalogue edit to
change a charge.

## Features

```http
GET    /api/v1/admin/subscription_features
POST   /api/v1/admin/subscription_features          { "subscription_feature": { "name": "...", "slug": "..." } }
PATCH  /api/v1/admin/subscription_features/:id
DELETE /api/v1/admin/subscription_features/:id
```

Deleting a feature attached to a plan deactivates it instead. The slug is the
identity the API enforces — renaming the display name is safe, changing the slug
is a code-level contract change (see `SubscriptionEntitlement` call sites).

## Manual assignment

```http
POST /api/v1/admin/billing/assignments
{ "owner_type": "Account", "owner_id": 42, "plan_slug": "coach", "reason": "Support ticket 1234" }
```

- `reason` is mandatory (`audit_reason_required` otherwise).
- Writes a history row with `source: admin` and actor id, plus a structured audit
  log event.
- Refuses when the owner's subscription is Stripe-managed
  (`subscription_stripe_managed`) — change it in Stripe instead.

## Inspection

```http
GET /api/v1/admin/billing/subscriptions?status=past_due&page=1&per_page=20
GET /api/v1/admin/billing/events?status=failed&per_page=20
GET /api/v1/admin/billing/diagnostics
```

Diagnostics returns presence of each secret (never values), the Price source per
plan, the enforcement flag, grace days and counters for billing records, customers,
events, failed events and open checkout sessions.

## Routine checks

- Failed events > 0 → inspect `error_message`; a correlation failure usually means
  a Price or Customer created outside this application.
- `price_configured: false` for a live plan → Checkout will fail for it; set the
  environment variable.
- Local record with `stripe_subscription_id` but the Stripe subscription is gone →
  reconciliation reports `missing_in_stripe`; decide with support whether to
  cancel locally or recreate.
- Manual assignment appears in the customer's billing history immediately.
