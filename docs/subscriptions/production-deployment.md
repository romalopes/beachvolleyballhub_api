# Production deployment

## 1. Database

```bash
bin/rails db:migrate            # creates the seven billing/catalogue tables
bin/rails db:seed               # idempotent: plans + features (safe to rerun)
```

Run migrations before the web process starts (Render's release command or a
one-off job). Seeds are safe on every deploy; they never overwrite admin edits.

## 2. Render environment variables

Set in the service's secret environment (never in the repository):

```
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PLAYER_YEARLY_PRICE_ID=price_...
STRIPE_COACH_YEARLY_PRICE_ID=price_...
STRIPE_CLUB_YEARLY_PRICE_ID=price_...
APP_FRONTEND_URL=https://app.beachvolleyballhub.com
BILLING_GRACE_PERIOD_DAYS=7
BILLING_ENFORCEMENT_ENABLED=true
# optional
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_SUCCESS_URL=https://app.../billing/return?checkout=success
STRIPE_CANCEL_URL=https://app.../billing/return?checkout=cancelled
STRIPE_PORTAL_RETURN_URL=https://app.../billing
```

The web dyno and the Solid Queue worker must both receive these: the worker runs
reconciliation.

## 3. Stripe live mode

1. Create the three live Products/Prices (AUD, yearly) and copy the IDs.
2. Add the webhook endpoint `https://<api-host>/api/v1/webhooks/stripe` with the
   nine events listed in [webhooks.md](webhooks.md). Copy its live signing secret.
3. Configure the Customer Portal (payment methods, invoices, cancellation policy,
   return URL).
4. Verify receipts/business details and the customer-facing support contact.

## 4. Cloudflare

- Allow POST `/api/v1/webhooks/stripe` from Stripe without bot challenges,
  Turnstile or body rewriting.
- Bypass cache for `/api/v1/billing/*` and the webhook.
- Rate-limit rules must not throttle Stripe; Rack::Attack already safelists it.
- Confirm HTTPS and the custom domain are correct for both SPA and API.

## 5. Verify after deploy

```bash
curl -s https://<api-host>/api/v1/subscriptions | head
curl -s https://<api-host>/api/v1/admin/billing/diagnostics   # as admin
```

- `/subscribe` lists the four plans with live prices.
- `diagnostics.billing.configured` is `true` and every live plan reports
  `price_configured: true` with source `environment`.
- Stripe Dashboard → Webhooks shows successful deliveries; the event table at
  `/settings/subscriptions` shows recent processed events.
- Run one low-value controlled live transaction if policy allows; confirm
  activation, receipt, Portal and cancellation.
- Trigger `BillingReconciliationJob` once manually and confirm a summary in logs.

## 6. Rollback

1. **Stop new subscriptions first**: temporarily hide paid plans
   (`visible: false`) or disable the Checkout button; existing entitlements keep
   working from the local mirror.
2. Roll back the application image. Do not roll back the database migrations while
   billing rows exist — the new columns are additive and old code ignores them.
3. If a webhook regression is suspected, point Stripe at a maintenance handler or
   disable the endpoint; events remain retried by Stripe for up to three days.
4. After recovery, run reconciliation to repair anything missed.
5. Never delete `billing_*` or `subscription_histories` rows to "clean up". A
   mismatch is investigated, not truncated.

## 7. Monitoring

- Alert on `billing.webhook.failed` / repeated `webhook.transient_failure`.
- Alert when `diagnostics.counts.failed_events` grows.
- Alert when reconciliation reports `missing_in_stripe` or `orphaned > 0`.
- Watch for repeated `invoice.payment_failed` for the same owner (customer action
  needed).
- Sentry already captures unhandled errors in the API process.

## 8. Rollout order

1. Migrate + seed (catalogue exists, nothing purchasable yet if plans are hidden).
2. Configure Stripe test mode, verify the flows with test cards.
3. Set live keys and Price IDs, enable enforcement, unhide plans.
4. Announce pricing, monitor the first renewals and failed payments.

## 9. Launch checklist

- [ ] AUD prices and yearly interval confirmed in Stripe live.
- [ ] One default FREE plan; Player/Coach/Club with the agreed features.
- [ ] Zero/null limit semantics approved.
- [ ] Stripe Customer Portal configured.
- [ ] Webhook endpoint verified in live mode.
- [ ] Cloudflare does not challenge the webhook.
- [ ] `BILLING_ENFORCEMENT_ENABLED` decision recorded.
- [ ] Reconciliation schedule active in the worker.
- [ ] Refund/dispute and support procedure agreed.
- [ ] Rollback procedure rehearsed (hide plans, roll back app, reconcile).
