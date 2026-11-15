# Phase 12 — Documentation and production launch

**Status:** complete (code and documentation); live resources and credentials are
operator actions

## Objective

Leave behind documentation that matches the implementation, plus a reproducible
launch and rollback procedure.

## Implemented documentation

| Document | Contents |
|---|---|
| `docs/subscriptions/README.md` | Orientation and current status |
| `architecture.md` | Components, owner model, data flow |
| `plans-and-features.md` | Catalogue, feature matrix, limit semantics, API shape |
| `billing-ownership.md` | Personal vs club ownership and permissions |
| `stripe-configuration.md` | Products/Prices, environment variables, CLI |
| `checkout.md` | Endpoint contract, flow, errors, return handling |
| `webhooks.md` | Events, guarantees, reconciliation, admin inspection |
| `subscription-lifecycle.md` | Upgrade/downgrade/cancel/renewal/grace |
| `entitlements-and-limits.md` | Resolver, status policy, enforcement matrix, quotas |
| `admin-guide.md` | Catalogue management, manual assignment, diagnostics |
| `security.md` | Threats, controls, Cloudflare, residual risks |
| `testing.md` | Automated and manual checklists |
| `production-deployment.md` | Render/Stripe/Cloudflare setup, verification, rollback |
| `troubleshooting.md` | Symptom → cause → action |

Phase records 00–12 live beside this file and record what was built, the decisions,
the files and the verification commands.

## Configuration summary (what must be set)

**API server (Render):**

- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- `STRIPE_PLAYER_YEARLY_PRICE_ID`, `STRIPE_COACH_YEARLY_PRICE_ID`,
  `STRIPE_CLUB_YEARLY_PRICE_ID`
- `APP_FRONTEND_URL`
- optional: `STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`, `STRIPE_PORTAL_RETURN_URL`,
  `BILLING_GRACE_PERIOD_DAYS`, `BILLING_ENFORCEMENT_ENABLED`,
  `STRIPE_PUBLISHABLE_KEY`

**Stripe:** three live annual AUD Products/Prices, one webhook endpoint with nine
events, Customer Portal configuration, business/receipt details.

**Cloudflare:** webhook allowed without challenge and uncached; billing responses
uncached; `/api/v1/webhooks/stripe` excluded from bot/rate rules that would block
Stripe.

**Frontend:** no billing secrets. It uses the existing `VITE_API_BASE_URL` and the
proxy; the new routes require no extra configuration.

**Database:** run migrations, then `db:seed`. The scheduler entry for
`BillingReconciliationJob` runs in the production Solid Queue worker.

## Launch checklist

- [ ] Stripe live Products/Prices created; Price IDs in Render.
- [ ] Webhook endpoint created and verified (test event returns 200).
- [ ] `diagnostics.billing.configured = true`, every plan
      `price_configured = true`, source `environment`.
- [ ] FREE is the only default plan; feature mappings match the approved catalogue.
- [ ] `BILLING_ENFORCEMENT_ENABLED` decision recorded.
- [ ] Reconciliation schedule active; one manual run logs a summary.
- [ ] Customer Portal opens for the correct owner.
- [ ] Return URLs point at the production SPA.
- [ ] Rollback rehearsal: hide paid plans, roll back the app, reconcile.
- [ ] Support/refund/dispute process agreed.
- [ ] First renewal and first failed payment monitored.

## Remaining launch blockers (operator decisions)

1. Confirm AUD and yearly pricing are final.
2. Confirm the feature catalogue names/mappings for public display.
3. Decide whether `BILLING_ENFORCEMENT_ENABLED` starts on (recommended once the
   premium operations are agreed).
4. Agree the grace period (default 7 days) and refund policy.
5. Create and secure the live Stripe keys (not stored in this repository).
