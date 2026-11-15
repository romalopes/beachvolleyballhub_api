# Architecture

## The problem this solves

BeachVolleyballHub has two kinds of customer: a person (Player/Coach) and a club
(Organisation). Both can pay, but for different things, and neither may see the
other's billing. The architecture keeps those two facts separate everywhere:
storage, Stripe Customers, API authorization, entitlement resolution and UI.

## Components

```
React SPA (beachvolleyballhub)
  /subscribe                 public pricing (GET /subscriptions)
  /billing                   personal billing  (owner = Current.user.account)
  /billing/return            checkout return  (polls GET /billing/status)
  /organisations/:id/billing club billing      (owner = Organisation)
  /settings/subscriptions    admin catalogue   (admin only)
        |
        v  cookie/bearer session
Rails API
  Api::V1::SubscriptionsController                    public catalogue
  Api::V1::Billing::{Status,Checkouts,Portals,Changes,Histories}Controller
  Api::V1::Webhooks::StripeController                 signed Stripe events only
  Api::V1::Admin::{Subscriptions,SubscriptionFeatures,
                   BillingAssignments,BillingRecords}Controller
        |
        v
  Billing::OwnerResolver          who may act for which billable owner
  Billing::CheckoutService        plan slug -> server Price -> Checkout Session
  Billing::PortalService          owner's own Stripe Customer -> Portal
  Billing::PlanChangeService      upgrade / downgrade / cancel / resume requests
  Billing::WebhookProcessor       idempotent, correlated event application
  Billing::ReconciliationService  daily repair + orphan detection
  Billing::AssignmentService      audited admin override
  Entitlements::Resolver          the single answer to "what may this owner use?"
  Entitlements::Quota / Usage     finite vs unlimited vs zero limits
        |
        v
PostgreSQL
  subscriptions, subscription_features,
  subscription_subscription_features      catalogue
  billing_customers                       owner -> Stripe Customer
  billing_subscriptions                   current state (one row per owner)
  billing_checkout_sessions               checkout correlation + reuse
  subscription_histories                  append-only lifecycle
  billing_events                          webhook idempotency + audit
```

## Data flow: a new Player subscription

1. The SPA POSTs `{ plan_slug: "player" }` to `/api/v1/billing/checkout`.
2. `OwnerResolver` resolves the personal Account from the session. No owner id is
   accepted for personal billing.
3. `CheckoutService` loads the visible plan, rejects FREE/non-purchasable plans,
   resolves the Stripe Price from server configuration and verifies via Stripe
   that it is AUD and yearly.
4. `CustomerService` creates or reuses the one Stripe Customer for that Account.
5. A Checkout Session is created in `subscription` mode with correlation
   metadata. `billing_checkout_sessions` records the session id and URL.
6. The browser is redirected to Stripe. **Nothing is granted.**
7. Stripe sends `checkout.session.completed` and/or
   `customer.subscription.created` to `/api/v1/webhooks/stripe`.
8. `WebhookProcessor` verifies the correlation: Customer -> owner, Price -> plan,
   metadata owner must match the Customer's owner. It writes
   `billing_subscriptions` and `subscription_histories` in one transaction and
   records the event id in `billing_events`.
9. The return page polls `/api/v1/billing/status`; only now is the plan reported
   as active, because the resolver reads the confirmed record.

## Ownership model

`billing_customers.billable` and `billing_subscriptions.billable` are polymorphic
with a database check constraint limiting them to `Account` and `Organisation`.
There is no second account/tenant system: an Account is the existing personal
identity, an Organisation is the existing club.

- One current billing record per owner (`UNIQUE (billable_type, billable_id)`).
- One Stripe Customer per owner (`UNIQUE (billable_type, billable_id)` and
  `UNIQUE stripe_customer_id`).
- History is not stored in the current record; it is appended to
  `subscription_histories`.

## Why the local mirror exists

The application must answer "may this person use this feature?" on every request
without calling Stripe. The mirror is written only by the webhook, reconciliation
or an audited admin assignment, and it carries Stripe's status verbatim. Stripe's
Price remains the money truth; the catalogue price is for display and comparison.

## Deliberate omissions

- No card data: Checkout and the Customer Portal are Stripe-hosted.
- No local invoices: the Portal is the invoice surface.
- No caching of entitlements: one indexed query is cheaper than a stale grant.
