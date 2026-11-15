# Phase 3 — Stripe configuration

**Status:** complete

## Objective

Make Stripe configuration server-side, validated and safe to fail, with the Price
for a plan resolved without trusting the browser.

## Implemented

- `app/services/billing/configuration.rb` — secret/webhook keys, frontend and
  return URLs, grace days, enforcement flag, Price environment key naming,
  `validate!`, `validate_api!`, `validate_webhook!`, safe `diagnostics`.
- `app/services/billing/price_catalog.rb` — `price_id_for(plan)` (environment
  first, database fallback), `price_source`, `plan_for_price_id` (reverse mapping,
  only configured Prices), `require_price_id!`.
- `app/services/billing/price_validator.rb` — retrieves the Price and rejects it
  unless it is the expected currency and yearly interval.
- `app/services/billing/stripe_gateway.rb` — the only class that touches the Stripe
  SDK. Configures `Stripe.api_key` from the environment, sets network retries, and
  exposes customer/checkout/portal/subscription/price/schedule/webhook operations
  as one stub-able seam.
- `Gemfile` — `stripe ~> 15.0`.

## Environment mapping

| Plan slug | Variable |
|---|---|
| player | `STRIPE_PLAYER_YEARLY_PRICE_ID` |
| coach | `STRIPE_COACH_YEARLY_PRICE_ID` |
| club | `STRIPE_CLUB_YEARLY_PRICE_ID` |

Secret key, webhook secret, frontend URL and optional overrides are documented in
`docs/subscriptions/stripe-configuration.md`.

## Decisions

- Environment wins over a database Price ID so test/live deployments cannot cross
  over; the DB column exists only for admin-created plans.
- Missing configuration is a 503 with the variable names, never a half-working
  integration and never a logged value.
- The publishable key is optional and unused: Checkout is hosted.
- Price validation happens when a Checkout Session is about to be created, not at
  boot, so a transient Stripe outage does not prevent the app from starting.

## Tests

No dedicated unit file; the configuration and Price mapping are exercised by:
- `test/services/billing/checkout_service_test.rb` — server Price resolution and
  the PriceValidator stub;
- `test/controllers/api/v1/billing_controller_test.rb` — `billing_not_configured`;
- `test/controllers/api/v1/admin/subscriptions_controller_test.rb` — diagnostics.

## Verification

```bash
bin/rails runner 'puts Billing::Configuration.diagnostics.inspect'
```
(Expect `missing_settings` to list Stripe keys in a development shell without
them, and no secret values anywhere in the output.)
