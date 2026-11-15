# Phase 6 — Upgrade, downgrade, cancellation and renewal

**Status:** complete

## Objective

Support the full paid lifecycle without ever granting a state Stripe has not
confirmed.

## Implemented

- `app/services/billing/plan_change_service.rb` — `change`, `cancel`, `resume`.
- `POST /api/v1/billing/change_subscription` (owner-scoped, club permission
  enforced by `OwnerResolver`).
- `Billing::Presenter#status` exposes `pending_change` (plan + effective date) and
  `cancel_at_period_end` to the UI.
- Webhook processor applies confirmed Price/status and clears pending fields.

## Rules

| Transition | Mechanism | Effective |
|---|---|---|
| FREE → paid | Checkout | on webhook confirmation |
| Player → Coach | Subscription update, item Price replacement, `always_invoice` proration | immediately after Stripe confirms |
| Coach → Player | Subscription Schedule phase change | next renewal |
| Paid → FREE | `cancel_at_period_end: true` | period end |
| Cancel reversal | `cancel_at_period_end: false` | immediately |
| Payment failure | `past_due` + grace | access until grace ends |

Local entitlement does not change during the request. `pending_subscription_id` and
`pending_change_requested_at` say “requested”, not “applied”.

## Concurrency

- `with_lock` on the billing record for changes.
- A second change within 10 minutes is refused (`subscription_change_pending`).
- Duplicate cancellation requests are idempotent (Stripe update only when not
  already cancelling).
- A timeout after a successful Stripe call is repaired by reconciliation, not by
  guessing locally.

## Tests

`test/services/billing/plan_change_service_test.rb` — upgrade payload + pending
state, deferred downgrade, cancel, resume, refusal to resume a non-cancelling
subscription, same-plan refusal, club permission failure, non-Stripe subscription
refusal.
Webhook tests cover the confirmation half (`invoice.paid`, subscription updated,
deleted).

## Verification

```bash
bin/rails test test/services/billing/plan_change_service_test.rb
```
