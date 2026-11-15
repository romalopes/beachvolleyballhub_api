# Subscription lifecycle

## Business rules (implemented)

| Change | Behaviour |
|---|---|
| FREE → paid | Stripe Checkout |
| Player → Coach (upgrade) | Immediate Stripe subscription update with `proration_behavior: "always_invoice"` |
| Coach → Player (downgrade) | Stripe Subscription Schedule: current Price until period end, then the new Price |
| Paid → FREE | Cancel at period end (`cancel_at_period_end: true`) |
| Cancel reversal | `resume` while the paid period is still running |
| Club changes | Only an active club owner/administrator (or site admin) |
| Personal changes | Only the personal owner |

The local plan **does not change** when the request is made. It changes when the
webhook reports Stripe's new Price/status. This is what keeps a failed upgrade
payment from taking away the plan the customer already paid for.

## Endpoint

`POST /api/v1/billing/change_subscription`

```json
{ "action": "change", "plan_slug": "coach" }
{ "action": "cancel" }
{ "action": "resume" }
```

Club requests add `owner_type: "organisation"` and `owner_id`.

The response is a request acknowledgement:

```json
{ "status": "pending_confirmation", "action": "upgrade", "plan_slug": "coach",
  "effective_at": "2026-11-14T...", "message": "Stripe is confirming the upgrade ..." }
```

## Upgrade

1. `PlanChangeService` compares catalogue prices to decide upgrade vs downgrade.
2. It reads the current Stripe subscription item id (not stored locally).
3. It updates the item to the new Price with immediate proration and payment
   collection.
4. It persists `pending_subscription_id`, `pending_change_requested_at` and
   `pending_change_effective_at` on the local record.
5. `customer.subscription.updated` applies the new Price, clears the pending
   fields and writes history.

If the prorated invoice fails, Stripe keeps the subscription and the local
entitlement stays on the old plan until Stripe reports a different state.

## Downgrade

`schedule_plan_change` creates a Subscription Schedule from the subscription with
two phases: the existing Price to the end of the paid period, then the new Price.
The customer keeps the current features until renewal. The local pending change is
shown on the billing page.

## Cancellation

- `cancel_at_period_end: true` in Stripe; access continues to `current_period_end`.
- The webhook sets `cancel_at_period_end` on the local record.
- `resume` reverses it before the period ends.
- If the period ends without resumption, `customer.subscription.deleted` sets
  `canceled` + `ended_at`, and the resolver falls back to FREE.

## Renewal

`invoice.paid`:

- clears `grace_period_ends_at`;
- extends `current_period_end` from the invoice line period;
- records a `renewal` history row when the period actually moved forward;
- never reactivates a `canceled` subscription.

## Failed payment / grace policy

`invoice.payment_failed` sets `past_due` and
`grace_period_ends_at = now + BILLING_GRACE_PERIOD_DAYS` (default 7) and records a
`payment_failed` history row. During the window the owner keeps paid access; after
it, the resolver falls back to FREE without deleting anything. Customer Portal is
the route to update the payment method.

## Concurrent requests

`PlanChangeService` locks the local billing record for the change path and refuses
a second change within 10 minutes
(`409 subscription_change_pending`). The webhook remains the single writer of the
confirmed state, so a timeout after a successful Stripe call is repaired by
reconciliation rather than guessed.

## State diagram (local record)

```
(incomplete) --payment ok--> (active) <--> (past_due) --grace expires--> FREE
     |                          |  \
     |                          |   cancel_at_period_end=true
     v                          v        |
(incomplete_expired)->FREE  (canceled) --+
                                ^
                                |
                    customer.subscription.deleted
```

`trialing` behaves like `active`. `unpaid` and `paused` behave like no paid access.
