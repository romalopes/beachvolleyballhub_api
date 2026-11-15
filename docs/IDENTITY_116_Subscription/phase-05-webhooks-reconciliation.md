# Phase 5 — Webhooks and reconciliation

**Status:** complete

## Objective

Keep the local mirror equal to Stripe, with idempotency, correlation, ordering
safety and a scheduled repair path.

## Implemented

- `app/controllers/api/v1/webhooks/stripe_controller.rb` — raw-body signature
  verification, no user auth, no test-access gate, 400 on bad signature, 503 when
  unconfigured, 500 on transient failure.
- `app/services/billing/webhook_processor.rb` — event ledger, correlation, state
  application, history, sanitised payload, out-of-order skipping.
- `app/services/billing/reconciliation_service.rb` and
  `app/jobs/billing_reconciliation_job.rb` — drift repair, orphan recreation,
  missing-in-Stripe reporting, structured summary.
- `config/recurring.yml` — `billing_reconciliation` daily at 03:17 in production.
- College events: checkout completed/async, subscription created/updated/deleted,
  invoice paid/payment_failed/finalization_failed.

## Correlation rules

1. Stripe Customer → `billing_customers` → owner. Unknown customer = failure.
2. Price → configured plan (`PriceCatalog`), then owner-type compatibility.
3. Metadata `owner_type`/`owner_id`, if present, must equal the Customer's owner.
4. A different Stripe subscription already stored for the owner = failure.
5. A Checkout row, when present, must belong to the same owner.

Permanent failures are recorded and acknowledged; transient ones are retried by
Stripe (5xx).

## Idempotency and ordering

- `billing_events.stripe_event_id` unique; processed/skipped duplicates return
  `duplicate`.
- Last applied event timestamp stored in the subscription metadata; an older event
  is marked `skipped` with an explanation and cannot revert newer state.

## Reconciliation

Daily job; also runnable manually. It feeds Stripe objects through the *same*
processor, so there is one interpretation of a Stripe subscription. Local records
with a vanished Stripe subscription are reported, never silently revoked.

## Tests

`test/services/billing/webhook_processor_test.rb` — activation + history, duplicate,
out-of-order, unknown Price, metadata mismatch, unknown customer, invoice failure
grace, invoice paid renewal, checkout completion, deletion, skipped event.
`test/services/billing/reconciliation_service_test.rb` — drift repair, missing
report, orphan recreation.
`test/controllers/api/v1/webhooks_stripe_controller_test.rb` — missing/invalid
signature, processed event without session, transient 500, unconfigured 503.

## Verification

```bash
bin/rails test test/services/billing/webhook_processor_test.rb \
  test/services/billing/reconciliation_service_test.rb \
  test/controllers/api/v1/webhooks_stripe_controller_test.rb
stripe listen --forward-to http://127.0.0.1:3001/api/v1/webhooks/stripe
stripe trigger invoice.payment_failed
```
