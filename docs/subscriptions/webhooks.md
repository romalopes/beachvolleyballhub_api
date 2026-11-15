# Webhooks

## Endpoint

`POST /api/v1/webhooks/stripe`

- No user session, no test-access gate: Stripe cannot present either.
- The Stripe signature is verified against the **raw request body** and
  `STRIPE_WEBHOOK_SECRET`. A request without a valid signature is rejected with
  `400 webhook_signature_invalid` and nothing is written.
- `200` means “received and processed (or permanently rejected)”; `5xx` means
  “retry me”.

## Subscribed events

| Event | Effect |
|---|---|
| `checkout.session.completed` | Correlates the session to its owner, marks the checkout row completed, activates when the subscription object is expanded |
| `checkout.session.async_payment_succeeded` | Same as completed |
| `checkout.session.async_payment_failed` | Logs; the session stays open for another attempt |
| `customer.subscription.created` | Creates/updates the local record and writes history |
| `customer.subscription.updated` | Applies the confirmed plan, status, period and cancellation state |
| `customer.subscription.deleted` | Records the cancellation (`canceled`, `ended_at`) |
| `invoice.paid` | Clears grace, extends the paid period, writes a `renewal` history row |
| `invoice.payment_failed` | Sets `past_due`, starts the grace window, writes `payment_failed` |
| `invoice.finalization_failed` | Logged for operators; no state change |

Unhandled event types are recorded as `skipped`; Stripe is acknowledged so it does
not retry them forever.

## Processing guarantees

1. **Idempotent.** `billing_events.stripe_event_id` is unique. A duplicate delivery
   is detected before any state change and returns `duplicate`.
2. **Correlated.** The Stripe Customer must map to a local owner
   (`billing_customers`), and the Price must map to a configured plan. Metadata
   `owner_type`/`owner_id` must agree with the Customer's owner. A mismatch is a
   permanent failure: recorded on the event, acknowledged to Stripe, visible to
   admins.
3. **Transactional.** Billing state, history and the event status are written in
   one transaction.
4. **Order-tolerant.** The processor stores the last applied event timestamp in
   `billing_subscriptions.metadata["last_event_created_at"]`. An older event for
   the same subscription is marked `skipped` as out-of-order instead of reverting
   newer state.
5. **No secrets in the audit.** The stored payload is recursively stripped of keys
   matching `secret|signature|card|cvc|cvv|client_secret`.

## Status mapping

Stripe statuses are stored verbatim: `incomplete`, `incomplete_expired`,
`trialing`, `active`, `past_due`, `canceled`, `unpaid`, `paused`.
`cancel_at_period_end` is a separate boolean, not a status. See
[entitlements-and-limits.md](entitlements-and-limits.md) for what each grants.

## Transient vs permanent failures

- Stripe API or database unavailable → the transaction rolls back, the event stays
  `received` with `attempts` incremented, and the endpoint returns `500` so Stripe
  retries with backoff.
- Correlation mismatch / invalid status / unknown Price → `failed`, `200` to
  Stripe. Repeated retries would reproduce the mismatch; an administrator must
  inspect `GET /api/v1/admin/billing/events?status=failed`.

## Reconciliation

`BillingReconciliationJob` runs daily in production (`config/recurring.yml`,
03:17). `Billing::ReconciliationService`:

1. Retrieves every local Stripe subscription and feeds it through the same
   `WebhookProcessor`, repairing a missed or rejected webhook.
2. Repairs a local record whose status/Price/period drifted.
3. Lists each known Customer's Stripe subscriptions and recreates any that have no
   local record (a missed `customer.subscription.created`).
4. Reports local records whose Stripe subscription no longer exists. It does
   **not** delete them or revoke access automatically — that needs a human
   decision.
5. Logs a structured summary (`billing.reconciliation.completed`).

Each repair is written to `billing_events` with a `reconciliation_...` id, so the
run leaves an audit trail. Running it twice is safe.

## Viewing webhook health

`GET /api/v1/admin/billing/events` (admin) lists recent events with status,
attempts and error. `GET /api/v1/admin/billing/diagnostics` includes failed-event
and open-checkout counts.
