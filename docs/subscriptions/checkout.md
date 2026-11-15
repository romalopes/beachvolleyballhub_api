# Checkout

## Endpoint

`POST /api/v1/billing/checkout` (authenticated)

```json
{ "plan_slug": "player" }
```

For a club:

```json
{ "plan_slug": "club", "owner_type": "organisation", "owner_id": 12 }
```

Response `201`:

```json
{ "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_...", "session_id": "cs_test_...", "reused": false }
```

## What the API does, in order

1. `Billing::Configuration.validate_api!` — fails 503 if the secret key is missing.
2. `Billing::OwnerResolver` resolves the owner:
   - personal: `Current.user.account` (no id accepted);
   - organisation: requires active owner/administrator membership of that club.
3. The plan must be `active`, `visible`, non-FREE and compatible with the owner
   type (`Subscription#purchasable?`, `#supports_owner?`).
4. An owner that already has a Stripe-managed subscription must change it instead
   (`409 subscription_already_active`).
5. An open Checkout Session for the same owner/plan younger than 30 minutes is
   returned with `reused: true` instead of creating a second one.
6. The Stripe Price is resolved **server-side** and verified as AUD/yearly.
7. `Billing::CustomerService` creates or reuses the owner's Customer.
8. A Checkout Session is created with `mode: subscription`, trusted success/cancel
   URLs and correlation metadata:
   `owner_type`, `owner_id`, `plan_id`, `plan_slug` (also copied to
   `subscription_data.metadata`), and `client_reference_id = "Type:id"`.
9. `billing_checkout_sessions` stores the session id, URL, expiry and owner
   correlation.

## What the browser may influence

Only the plan slug and (for clubs) the owner id — both re-validated. The browser
cannot set the amount, currency, Stripe Price ID, customer, success URL or
metadata.

## Success / cancel URLs

Built from `APP_FRONTEND_URL` (or `STRIPE_SUCCESS_URL`/`STRIPE_CANCEL_URL`):

```
${APP_FRONTEND_URL}/billing/return?checkout=success&session_id={CHECKOUT_SESSION_ID}
${APP_FRONTEND_URL}/billing/return?checkout=cancelled&session_id={CHECKOUT_SESSION_ID}
```

Stripe substitutes `{CHECKOUT_SESSION_ID}`. The application never treats that
value as proof of payment.

## The return page

`/billing/return` (React):

- `checkout=cancelled` → “no payment was taken”, links back.
- `checkout=success` → polls `GET /billing/status` up to 10 times at 2s intervals.
  It shows “Activating your plan…” and then the confirmed plan. If the webhook is
  late it shows “Still processing” with a link to billing; it never grants access.

## Idempotency and duplicates

- `X-Idempotency-Key` is honoured by the existing API middleware, so a retried
  POST returns the same response.
- The 30-minute reusable-session rule prevents a double-click from creating two
  Stripe sessions.
- One active subscription per owner is enforced by `billing_subscriptions` and by
  the `AlreadySubscribed` check.

## Common errors

| HTTP | Code | Meaning |
|---|---|---|
| 400 | `invalid_owner_type` | Unsupported owner type |
| 403 | `billing_owner_not_eligible` | Not the personal owner or a club billing manager |
| 409 | `subscription_already_active` | Change the existing subscription instead |
| 422 | `subscription_plan_not_purchasable` | Unknown, hidden, inactive or FREE plan |
| 422 | `subscription_plan_incompatible` | e.g. Club plan for a personal owner |
| 503 | `billing_not_configured` | Missing server secret |
| 503 | `stripe_price_not_configured` | No Price mapped for the plan |
| 503 | `stripe_price_invalid` | Price is not AUD/yearly |
