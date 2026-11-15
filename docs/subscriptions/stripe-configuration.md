# Stripe configuration

## Environments

Use separate Stripe **test** and **live** accounts (or at minimum separate test and
live mode keys). Never mix Price IDs between them. The API takes every credential
from its own environment, so a staging deployment can point at test mode while
production points at live mode.

## Required server environment variables

| Variable | Required | Purpose |
|---|---|---|
| `STRIPE_SECRET_KEY` | yes | Server API calls (Customers, Checkout, Portal, Subscriptions) |
| `STRIPE_WEBHOOK_SECRET` | yes | Signature verification of `/api/v1/webhooks/stripe` |
| `STRIPE_PUBLISHABLE_KEY` | optional | Not used by the SPA today; reserved |
| `STRIPE_PLAYER_YEARLY_PRICE_ID` | yes for Player | Server-side Price mapping |
| `STRIPE_COACH_YEARLY_PRICE_ID` | yes for Coach | Server-side Price mapping |
| `STRIPE_CLUB_YEARLY_PRICE_ID` | yes for Club | Server-side Price mapping |
| `APP_FRONTEND_URL` | yes | Base URL used to build return URLs |
| `STRIPE_SUCCESS_URL` | optional | Override the Checkout success URL |
| `STRIPE_CANCEL_URL` | optional | Override the Checkout cancel URL |
| `STRIPE_PORTAL_RETURN_URL` | optional | Customer Portal return URL |
| `BILLING_GRACE_PERIOD_DAYS` | optional (default 7) | Failed-payment grace window |
| `BILLING_ENFORCEMENT_ENABLED` | optional | `true` enables premium endpoint enforcement |

Price variable names are derived: `STRIPE_<SLUG>_YEARLY_PRICE_ID`. A plan may also
carry a `stripe_price_id` column (set through the admin UI) as a fallback, but the
environment variable wins so test and live stay separate.

**Never** put any of these in `VITE_*` variables or in the frontend repository.

## Stripe Dashboard setup (test mode)

1. Products → create three annual products:
   - `BeachVolleyballHub Player` — AUD 5.00 / year, recurring
   - `BeachVolleyballHub Coach` — AUD 10.00 / year, recurring
   - `BeachVolleyballHub Club` — AUD 50.00 / year, recurring
2. Copy each Price ID (`price_...`) into the matching environment variable.
   FREE has no Product or Price.
3. Developers → Webhooks → add endpoint
   `https://<api-host>/api/v1/webhooks/stripe` with events:
   `checkout.session.completed`, `checkout.session.async_payment_succeeded`,
   `checkout.session.async_payment_failed`, `customer.subscription.created`,
   `customer.subscription.updated`, `customer.subscription.deleted`,
   `invoice.paid`, `invoice.payment_failed`, `invoice.finalization_failed`.
4. Copy the endpoint signing secret (`whsec_...`) into
   `STRIPE_WEBHOOK_SECRET`.
5. Billing → Customer portal → enable payment-method updates, invoice history and
   cancellation (if the product wants self-service cancellation) and set the
   return URL to `${APP_FRONTEND_URL}/billing`.

## Startup validation

`Billing::Configuration#validate_api!` (Checkout/Portal/plan changes) fails with
`billing_not_configured` naming the missing variable, without printing values.
`validate_webhook!` does the same for the webhook secret. `validate!` requires both
and is used by reconciliation.

`GET /api/v1/admin/billing/diagnostics` reports presence (not values) of each
setting, the Price source per plan (`environment` or `database`) and counters.

## Price verification

Before creating a Checkout Session, `Billing::PriceValidator` retrieves the
configured Price from Stripe and rejects anything that is not `AUD` and
`recurring.interval = year`. This runs once per Checkout creation and prevents a
test-mode / wrong-interval Price from ever being charged.

## Local development with the Stripe CLI

```bash
stripe login
stripe listen --forward-to http://127.0.0.1:3001/api/v1/webhooks/stripe
# copy the printed whsec_... into STRIPE_WEBHOOK_SECRET, restart Rails
```

Trigger test events:

```bash
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
stripe trigger invoice.payment_failed
```

Because the private test-access gate (`TEST_ACCESS_PASSWORD`) would block Stripe,
the webhook controller opts out of it and of user authentication; the signature is
the authentication.

## What is intentionally not configurable

- Card data — Stripe Checkout/Portal only.
- Client-supplied amounts, currencies or Price IDs — rejected by never reading
  them. The API accepts a plan slug and resolves everything else.
