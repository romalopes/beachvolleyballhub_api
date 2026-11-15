# Phase 10 — Security and operational reliability

**Status:** complete

## Objective

Review and harden the integration: authorization, secrets, idempotency, rate
limits, Cloudflare compatibility and observability.

## Implemented

- Owner-scoped authorization for every billing action
  (`Billing::OwnerResolver`), including the “no owner id for personal billing” rule.
- Webhook signature verification over the raw body; no auth/test-gate bypass that
  skips the signature.
- Stable error codes without subscription or payment leakage in bodies.
- Rack::Attack:
  - safelist `/api/v1/webhooks/stripe` (a throttled webhook is a failed payment);
  - 10/min throttle for Checkout, Portal and plan-change POSTs.
- Idempotency: existing `X-Idempotency-Key` middleware + unique Stripe event ids +
  reusable Checkout windows + one-subscription-per-owner constraints.
- `Billing::AuditLogger` — JSON `billing.*` events for checkout created/reused,
  webhook received/processed/duplicate/skipped/failed, subscription sync, invoice
  paid/payment failed, plan changes, cancellation, portal, admin assignment,
  reconciliation.
- Payload sanitisation removes secret/signature/card/client-secret keys before
  storing a webhook event.
- `config/initializers/filter_parameter_logging.rb` already filters `secret`,
  `token`, `_key`, `cvv`, `cvc`; billing secrets additionally never enter params.
- Reconciliation + daily job + diagnostics counters for operational detection.

## Cloudflare notes

Documented in `docs/subscriptions/security.md` and
`production-deployment.md`: allow the webhook without bot challenge, do not cache
billing responses, do not rewrite the webhook body.

## Tests

- `billing_controller_test.rb` — unauthenticated 401, non-manager organisation 403,
  free/paid status, configured failure, checkout happy path.
- `webhooks_stripe_controller_test.rb` — missing/invalid signature, 500 for
  transient failure, 503 unconfigured.
- `webhook_processor_test.rb` — duplicate, out-of-order, unknown price, metadata
  mismatch, unknown customer.
- `subscription_enforcement_test.rb` — direct API bypass on FREE, admin bypass.

## Residual risks

- Admin compromise can assign plans; it is audited, not prevented.
- Stripe outage blocks new checkouts; existing entitlements continue from the local
  mirror.
- Turnstile is not integrated; if added to Checkout it must be verified server-side
  and is not authentication.

## Verification

```bash
bin/rubocop app/services/billing app/services/entitlements \
  app/controllers/api/v1/billing app/controllers/api/v1/webhooks \
  app/controllers/concerns/subscription_entitlement.rb
```
All inspected files pass the project's RuboCop configuration.
