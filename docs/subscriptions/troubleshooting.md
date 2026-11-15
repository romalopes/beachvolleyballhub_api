# Troubleshooting

## A customer paid but the plan did not activate

1. Check `/settings/subscriptions` → recent webhook events (or
   `GET /api/v1/admin/billing/events`).
2. No event for the session? Stripe Dashboard → Webhooks → recent deliveries.
   A 400 means signature verification failed (wrong `STRIPE_WEBHOOK_SECRET`); a
   5xx means the API failed transiently and Stripe will retry; no delivery means
   the endpoint URL or Cloudflare rules are wrong.
3. Event `failed` with “No local owner for Stripe customer” → the Checkout was
   started outside this app or `billing_customers` was not written. Compare the
   Customer id in Stripe with `billing_customers`.
4. Event `failed` with “… is not in the plan catalogue” → the Price in Stripe is
   not one of the configured `STRIPE_*_YEARLY_PRICE_ID` values (often a test-mode
   Price in live mode).
5. After fixing configuration, run reconciliation or resend the event from Stripe.

## Return page keeps saying “Still processing”

The webhook is late or failing. The plan is not granted from the redirect by
design. Check the events table; do not “fix” it by editing the local record unless
Stripe confirms the subscription.

## Checkout returns `subscription_already_active`

The owner already has a Stripe-managed subscription. Use “Change plan” in
`/billing`; a second Checkout would create a second subscription.

## Checkout returns `billing_not_configured`

`STRIPE_SECRET_KEY` is missing on the API process. Diagnostics shows which
settings are missing (names only).

## Checkout returns `stripe_price_not_configured`

`STRIPE_<SLUG>_YEARLY_PRICE_ID` is missing and the plan has no fallback
`stripe_price_id`. Add the variable and restart.

## Checkout returns `stripe_price_invalid`

The configured Price is not AUD or not yearly. Fix it in Stripe; the API verifies
before charging.

## A club owner gets 403 on `/organisations/:id/billing`

- They are not an active `owner`/`administrator` of that exact club (membership
  hierarchy is not access).
- Or they are a club administrator but the deployment enabled enforcement and the
  club has no Club plan — the *status* endpoint itself is not feature-gated; this
  403 is more likely the membership check.

## A member can see the club billing page

They should receive an error from the API. If they see data, check that the SPA is
passing the organisation id and that the API version is the one containing
`Billing::OwnerResolver`.

## Premium endpoint still works on FREE

- `BILLING_ENFORCEMENT_ENABLED` is not `true` on that process.
- The caller is an admin/curator (intentional bypass).
- The endpoint is not mapped to a feature yet — see the matrix in
  [entitlements-and-limits.md](entitlements-and-limits.md).

## `past_due` customer lost access immediately

Expected only after `grace_period_ends_at`. If it happened earlier, the resolver
read a record with no grace window: check that `invoice.payment_failed` was
processed (a missed webhook leaves the old `active` status instead, which grants
access; it should not revoke early).

## Duplicate webhook created two history rows

History is written once per meaningful change; a duplicate event is skipped before
processing. If you see two rows, check whether they are genuinely different
transitions (activation then renewal) or whether the event ids differ (Stripe sent
two distinct events).

## Reconciliation reports `missing_in_stripe`

The local record points at a Stripe subscription that no longer exists. It does not
revoke access automatically. Investigate: was it deleted in the dashboard? Then
apply the confirmed state (cancel locally via support tooling or let Stripe’s
`customer.subscription.deleted` arrive).

## Tests fail with `PG::UndefinedTable: subscription_features`

Parallel test workers hold old databases. Stop test processes, drop
`beachvolleyballproject_test_0..N`, and re-run:

```bash
psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname LIKE 'beachvolleyballproject_test%'"
for i in 0 1 2 3 4 5 6 7 8 9; do dropdb --if-exists beachvolleyballproject_test_$i; done
RAILS_ENV=test bin/rails db:test:prepare
bin/rails test
```

## Frontend billing page shows “Failed to load billing”

- Not signed in → sign in.
- `404`/`403` → wrong owner id or no billing permission.
- `503 billing_not_configured` → server configuration, not the SPA.
- CORS/proxy misconfiguration → check `VITE_API_BASE_URL` and the Vercel rewrite.
