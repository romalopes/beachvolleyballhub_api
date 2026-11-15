# Phase 4 — Checkout and billing API

**Status:** complete

## Objective

Let an authorised owner start a paid subscription and read their billing state,
without the browser ever influencing money or ownership.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/subscriptions` | public | Visible active plans + features |
| GET | `/api/v1/billing/status` | user | Owner's billing state (personal by default) |
| POST | `/api/v1/billing/checkout` | user | Create/reuse a Checkout Session |
| POST | `/api/v1/billing/portal` | user | Open the Customer Portal |
| POST | `/api/v1/billing/change_subscription` | user | change / cancel / resume |
| GET | `/api/v1/billing/history` | user | Append-only lifecycle history |
| GET/POST/PATCH/DELETE | `/api/v1/admin/subscriptions` | admin | Plan catalogue |
| PUT | `/api/v1/admin/subscriptions/:id/features` | admin | Ordered feature mapping |
| GET/POST/PATCH/DELETE | `/api/v1/admin/subscription_features` | admin | Feature catalogue |
| POST | `/api/v1/admin/billing/assignments` | admin | Audited manual assignment |
| GET | `/api/v1/admin/billing/subscriptions` | admin | Billing records |
| GET | `/api/v1/admin/billing/events` | admin | Webhook ledger |
| GET | `/api/v1/admin/billing/diagnostics` | admin | Configuration presence/counters |

## Implemented

- Controllers under `app/controllers/api/v1/billing/` (base + status, checkouts,
  portals, changes, histories), `subscriptions_controller.rb`, `webhooks/`, and
  `admin/{subscriptions,subscription_features,billing_assignments,billing_records}_controller.rb`.
- Services: `Billing::OwnerResolver`, `Billing::OwnerContact`,
  `Billing::CustomerService`, `Billing::CheckoutService`, `Billing::PortalService`,
  `Billing::PlanChangeService`, `Billing::AssignmentService`,
  `Billing::Presenter`, `Billing::HistoryRecorder`, `Billing::AuditLogger`.
- Routes in `config/routes.rb`; `SubscriptionEntitlement` concern included where
  protected.

## Security behaviour

- Personal billing never accepts an owner id.
- Organisation billing requires active owner/administrator membership of that
  exact club; admins may act in support.
- Plan must be visible, active, non-FREE and owner-compatible.
- Checkout takes a plan slug only; Price, amount, currency, Customer and metadata
  are server-side.
- Repeated Checkout requests reuse an open session (< 30 min) instead of creating a
  second one; an owner with a Stripe-managed subscription is told to change it.
- Errors use stable codes (`billing_owner_not_eligible`,
  `subscription_already_active`, `subscription_plan_incompatible`, …).

## Tests

`test/controllers/api/v1/subscriptions_controller_test.rb` (public catalogue, no
Price IDs), `billing_controller_test.rb` (auth, free/paid status, organisation
permissions, configuration failure, checkout happy path, plan incompatibility,
history), `admin/subscriptions_controller_test.rb` (non-admin denial, CRUD,
deactivation, feature replacement, diagnostics), plus the service tests.

## Verification

```bash
bin/rails test test/controllers/api/v1/subscriptions_controller_test.rb \
  test/controllers/api/v1/billing_controller_test.rb \
  test/controllers/api/v1/admin/subscriptions_controller_test.rb \
  test/services/billing/checkout_service_test.rb
```
