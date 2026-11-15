# Security

## Assets

- Stripe secret key and webhook signing secret.
- Customers' billing state and invoice history.
- The integrity of entitlement decisions.

## Controls

| Threat | Control |
|---|---|
| Forged payment via URL | The webhook is the only writer; `/billing/return` merely polls |
| Client-supplied price/amount | The API accepts a plan slug only; Price is resolved server-side and validated (AUD/yearly) |
| IDOR on owner ids | Personal billing always uses the session's Account; organisation ids require active owner/administrator membership |
| Cross-owner data leaks | History/status queries are scoped by owner; members without billing rights get `403` |
| Duplicate/replayed webhook | Unique `stripe_event_id`, transactional processing, duplicate detection |
| Out-of-order webhook | Last-applied event timestamp per subscription; stale events are skipped |
| Customer/plan mismatch | Customer → owner and Price → plan must resolve; metadata must agree; mismatches fail closed |
| Webhook blocking (WAF/Turnstile) | Endpoint safelisted in Rack::Attack and documented for Cloudflare |
| Brute force / session spam | Checkout, Portal and plan-change endpoints throttled 10/min per principal |
| Secret leakage | Filtered parameters, diagnostics report presence only, no secrets in audit payloads or errors |
| Card data exposure | None stored or transmitted through this app; Stripe hosted Checkout/Portal |
| An owner deleting billing history | `restrict_with_error`; billing rows are never cascaded |
| Admin misuse | Admin-only endpoints, mandatory assignment reason, append-only history, audit log events |

## Webhook specifics

- Signature verified over the raw body with the endpoint secret.
- Missing secret → `503`, missing signature → `400`, invalid signature → `400`.
- Only identifiers and sanitised payloads are stored; keys matching
  `secret|signature|card|cvc|cvv|client_secret` are removed before persistence.
- The endpoint is exempt from the private test-access gate and user authentication;
  it is *not* exempt from signature verification.

## Logging

Structured JSON events with the `billing.` prefix: checkout created/reused,
webhook received/processed/duplicate/skipped/failed, subscription synced, invoice
paid/payment failed, plan change requested, cancellation, portal created, admin
assignment, reconciliation summary. Owner type/id, plan slug and Stripe ids are
included where useful; emails, card details and secrets are not.

## Rate limiting

`config/initializers/rack_attack.rb`:

- the general IP/user throttle still applies to billing reads;
- `/api/v1/webhooks/stripe` is safelisted (a throttled webhook is a failed payment);
- POSTs to `/api/v1/billing/checkout`, `/portal` and `/change_subscription` are
  limited to 10/minute per bearer token or IP.

## Cloudflare

- WAF/rate-limit billing endpoints, but never challenge the Stripe webhook with
  Turnstile or interactive bot checks.
- Do not cache `/api/v1/billing/*` or `/api/v1/webhooks/stripe`.
- Do not rewrite methods or bodies for the webhook path.
- If Turnstile is added to Checkout initiation, verify the token server-side; it is
  extra abuse control, not authentication.

## Testing the controls

`test/controllers/api/v1/billing_controller_test.rb` (auth, owner authorization),
`webhooks_stripe_controller_test.rb` (signature, 5xx retry, unconfigured),
`subscription_enforcement_test.rb` (direct API bypass attempts, admin bypass),
`test/services/billing/webhook_processor_test.rb` (duplicate, out-of-order,
mismatch), `test/models/subscription_test.rb` (catalogue invariants).

## Known residual risks

- A compromised admin account can assign plans; the audit trail makes it visible
  but not impossible.
- Stripe is a hard dependency for starting a subscription; existing entitlements
  keep working from the local mirror if Stripe is unreachable.
- Reconciliation trusts Stripe's Customer mapping; a Customer created manually in
  the Stripe dashboard without a local mapping is reported, not adopted.
