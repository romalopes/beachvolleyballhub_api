# BeachVolleyballHub — Subscription & Stripe Billing Implementation Plan

**Status:** Proposed  
**Date:** 14 November 2026  
**Repositories:**  
- API: https://github.com/romalopes/beachvolleyballhub_api
- Frontend: https://github.com/romalopes/beachvolleyballhub_frontend

**Reference implementation:**  
- Wine Words API: https://github.com/romalopes/wine_words_api
- Wine Words frontend: https://github.com/romalopes/wine_words_front_end
- Wine Words subscription architecture: https://github.com/romalopes/wine_words_api/issues/22

---

## 1. Objective

Implement a configurable subscription system for BeachVolleyballHub using Stripe Billing, reusing the proven subscription catalogue, feature catalogue, subscription history, admin management and frontend patterns from Wine Words.

The implementation must support:

- Free and paid annual plans.
- Stripe Checkout for new paid subscriptions.
- Stripe webhooks as the authoritative source of payment/subscription state.
- Stripe Customer Portal for payment method updates and cancellation where suitable.
- Subscription upgrades, downgrades and renewal handling.
- Personal subscriptions for Player and Coach.
- Organisation-owned Club subscriptions.
- Configurable features and usage limits.
- Subscription history and lifecycle audit logs.
- Administration tools to manage plans, features and assignments.
- Consistent access enforcement in Rails APIs and React UI.
- Secure operation in local, staging/test and production environments.

Do not copy Wine Words code blindly. Inspect the current BeachVolleyballHub models, authentication, Account membership, roles, organisation model, API conventions, frontend routing and deployment configuration before implementation.

## 2. Reference architecture and lessons

Wine Words Issue #22 established the following useful patterns:

- Subscription catalogue with `name`, `slug`, visibility, active/default flags, description, prices, currency and position.
- Standalone feature catalogue and a many-to-many subscription-feature join model.
- User subscription history.
- A default FREE subscription.
- Role separation: subscription controls only the base access role, not privileged roles.
- Public listing of visible/active plans and restricted administrative CRUD.
- Deactivation rather than deletion when a plan has history or assigned users.

Related Wine Words issues to inspect during implementation:

- #77 — Stripe payment flow, webhook activation, idempotency and avoiding trust in browser redirects.
- #73 — Preventing invalid downgrades and handling plan changes.
- #80 — Partial payment/proration when upgrading.
- #93 — Unified subscription changes, renewal correctness, reconciliation and lifecycle audit logging.
- #76 — Choosing a subscription during user creation.

Important lessons from #77:

1. A successful browser redirect is not proof of payment.
2. The Stripe webhook must be authoritative for activating a paid subscription.
3. Checkout Session, Stripe Customer, application owner and purchased Price/plan must be correlated safely.
4. Webhook processing must be idempotent.
5. Frontend must refresh subscription state from the API after returning from Checkout.
6. API base URL construction must avoid duplicated slashes.
7. Log checkout creation, webhook receipt, activation, duplicate events and reconciliation failures.

Use current Stripe Products and Prices, not the legacy Stripe Plan object.

Recommended Stripe pattern:
- Stripe Billing subscriptions.
- Stripe Checkout Sessions with `mode: subscription`.
- Stripe Customer Portal for self-service billing management.
- Signed webhooks.
- Local database mirror of relevant Stripe state.
- Periodic reconciliation against Stripe.

## 3. Subscription plans

All prices below are assumed to be AUD and annual. Confirm this before creating production Stripe Prices.

| Plan | Annual price | Default | Users | History | Features |
|---|---:|:---:|---:|---:|---:|
| FREE | $0 | Yes | 0 | 0 | 0 |
| Player | $5 | No | 0 | 0 | 1 |
| Coach | $10 | No | 0 | 0 | 3 |
| Club | $50 | No | 0 | 0 | 5 |

### 3.1 Important definition of limits

The meaning of `Users = 0` and `History = 0` must be confirmed before enforcement is implemented.

Do not assume zero means unlimited or zero access. Define explicit semantics, for example:

- `0` = no additional seats / no historical retention entitlement;
- `nil` = unlimited / not applicable;
- a positive integer = explicit quota.

If the intended meaning is unlimited, use `nil` or an explicit `unlimited` flag rather than overloading zero.

For personal plans, clarify whether the owner counts as a user. For Club, clarify whether the Club plan includes any seats, and whether club members need individual accounts or paid personal subscriptions.

Recommended initial model:
- `included_users` nullable integer.
- `history_limit` nullable integer or a separately defined retention value.
- `nil` means unlimited/not limited by this entitlement.
- `0` means none beyond the explicitly documented owner access.
- Add a `limit_unit` or feature-specific limit metadata if different quotas need different units.

### 3.2 Proposed ownership

Do not attach every subscription directly to `User`.

Use subscription ownership that supports:
- Personal account subscription: Player and Coach.
- Organisation subscription: Club.

A personal user may be a member of a Club that has its own subscription. Those subscriptions are independent.

Examples:
- A Coach may pay for Coach features personally and also belong to a Club.
- The Club's subscription unlocks organisation-level features.
- A Club subscription does not automatically make every member a paid Coach.
- A personal plan does not grant organisation-wide entitlements.

Inspect the existing Account / Person / PlayerProfile / CoachProfile / organisation membership model. Prefer integrating with the existing Account abstraction if it can represent both personal and organisation ownership cleanly. Do not introduce a second account/tenant system.

If the existing model cannot safely represent both owner types, use a polymorphic billable owner (`PersonalAccount` / `Organisation`) with explicit validations and database constraints. Avoid an unconstrained generic polymorphic association if a clearer existing model is available.

### 3.3 Initial feature catalogue proposal

The counts in the plan table represent the number of feature catalogue entries assigned to each plan, not hardcoded feature flags.

Illustrative catalogue (confirm product scope before release):

| Feature | Player | Coach | Club |
|---|:---:|:---:|:---:|
| Enhanced personal player profile | ✓ | ✓ | ✓ |
| Advanced training planning | | ✓ | ✓ |
| Advanced assessments and player development | | ✓ | ✓ |
| Organisation management | | | ✓ |
| Club-level reporting and management | | | ✓ |

The feature names and mapping are proposals. Admins should be able to manage the catalogue and plan-feature associations without code changes.

Keep four concepts separate:
- Roles: identity and authorization (Player, Coach, Admin, Curator, etc.).
- Features: capabilities available under a plan.
- Limits: quantities or quotas.
- Subscription state: whether the entitlement is currently active.

A Coach can remain a Coach without a paid Coach plan; premium Coach features are then unavailable. Subscription changes must not remove privileged roles.

---

# 4. Phased implementation

## Phase 0 — Repository audit and architecture decisions

### API audit
Inspect:
- Rails version, Ruby version and dependency conventions.
- User, Account, Person, PlayerProfile and CoachProfile models.
- Organisation model and membership relationships.
- Role/permission implementation and authorization policies.
- Existing subscription/payment/billing code, if any.
- API namespace, serializers and response conventions.
- Current migrations and database indexes.
- Background job adapter and scheduled job mechanism.
- Existing audit logging and notification patterns.
- Environment variable handling and deployment configuration.
- Existing tests and CI quality gates.

### Frontend audit
Inspect:
- React/Vite version and routing.
- API client and API base URL construction.
- Authentication state and current-user bootstrap.
- Account settings and organisation settings.
- Existing role-aware navigation and route guards.
- Existing pricing or subscription UI.
- UI component and form conventions.
- Error handling, toast/notification patterns and loading states.
- Mobile/PWA navigation and responsive layouts.

### Deliverables
- Architecture decision record for subscription owner.
- Confirmed definitions for Users and History limits.
- Approved list of five Club/Coach/Player features.
- Mapping of relevant Wine Words files/classes to BeachVolleyballHub equivalents.
- List of reusable code versus code that must be redesigned.

### AI prompt
> Inspect the BeachVolleyballHub API and frontend repositories and the Wine Words API/frontend subscription implementation. Use Wine Words Issue #22 and related Stripe issues #77, #73, #80 and #93 as references. Do not modify code. Produce an architecture audit covering current authentication, Account/Organisation ownership, roles, membership, API conventions, frontend routes, Stripe dependencies, background jobs and test patterns. Recommend how to support personal Player/Coach subscriptions and organisation-owned Club subscriptions without duplicating the existing tenant/account model. Identify ambiguities in the plan limits and list exact files/classes that should be inspected or reused.

## Phase 1 — Subscription data model

### 1. `subscriptions`
Suggested fields:
- `name`
- `slug` (unique)
- `description`
- `active`
- `visible`
- `popular`
- `is_default`
- `position`
- `currency` (default AUD)
- `yearly_price_cents`
- `included_users` (nullable)
- `history_limit` (nullable)
- `owner_type` or supported owner categories, if required
- timestamps

Use integer cents for money. Enforce one default plan with a partial unique index. Ensure only one active default FREE plan exists.

Do not make plan price changes silently alter existing Stripe subscriptions. Existing Stripe subscriptions retain their Price until an explicit migration/change strategy is applied.

### 2. `subscription_features`
Suggested fields:
- `name`
- `slug` (unique)
- `description`
- `active`
- `position`
- timestamps

### 3. `subscription_subscription_features`
Join table:
- `subscription_id`
- `subscription_feature_id`
- `position`
- unique composite index
- timestamps if consistent with project conventions

### 4. Subscription ownership and history

Recommended logical model:
- `subscriptions`: catalogue of plans.
- `subscription_features`: catalogue of capabilities.
- `subscription_subscription_features`: plan-feature associations.
- `subscriptions` assigned to a billable owner through a current subscription record.
- `subscription_histories` (or `user_subscriptions` adapted to the owner model): immutable lifecycle history.
- `billing_customers`: Stripe customer mapping for a billable owner, if not safely represented on the owner.
- `billing_events`: webhook idempotency and processing audit, or an equivalent existing event store.

History should record:
- owner
- subscription/plan
- start/end timestamps
- status
- source (`admin`, `checkout`, `webhook`, `migration`, etc.)
- Stripe subscription and price identifiers where applicable
- cancellation and change timestamps
- relevant metadata

Do not rely only on `users.subscription_id`, because a Club is not necessarily a User. If the existing Account model is the correct billable owner, use it consistently.

### 5. Stripe identifiers

Persist only the identifiers required to reconcile application state:
- Stripe Customer ID
- Stripe Subscription ID
- Stripe Price ID
- Stripe Product ID if needed
- Stripe Checkout Session ID where useful for audit
- latest invoice/payment state references as appropriate

Never store card numbers, CVCs or raw payment credentials.

### 6. Soft deletion and catalogue safety

- Plans assigned to owners or referenced by history must not be hard-deleted.
- Deactivate and hide them instead.
- Features referenced by plans/history should also be deactivated rather than destructively removed.
- Protect default plan and referential integrity at the database level where possible.

### Models and services
Potential classes (adapt names to existing conventions):
- `Subscription`
- `SubscriptionFeature`
- `SubscriptionSubscriptionFeature`
- `SubscriptionHistory`
- `BillingCustomer`
- `BillingEvent`
- `Billing::CheckoutSessionService`
- `Billing::WebhookProcessor`
- `Billing::SubscriptionSynchronizer`
- `Billing::PlanChangeService`
- `Entitlements::Resolver`
- `Entitlements::FeatureAccess`

### AI prompt
> Implement the BeachVolleyballHub subscription schema after the Phase 0 audit. Reuse the Wine Words catalogue/history design where appropriate, but support both personal and organisation-owned subscriptions. Use AUD cents, annual pricing, a single default FREE plan, feature catalogue and ordered plan-feature associations. Clarify and encode the zero/null limit semantics. Add foreign keys, unique indexes, validations, safe deactivation and migration tests. Do not couple subscriptions to volleyball roles. Provide migration rollback checks and model specs.

## Phase 2 — Plan catalogue, seeds and entitlements

### Seeds
Create an idempotent seed task, for example `db/seeds/subscriptions.rb`, called from the main seeds file.

Seed:
- FREE: 0 cents, default, visible and active.
- Player: 500 cents/year.
- Coach: 1000 cents/year.
- Club: 5000 cents/year.

Seed feature catalogue entries and associations. Seeds must update existing records safely without resetting production customisations unnecessarily.

### Entitlement resolver
Implement a central service, such as `Entitlements::Resolver`, that resolves effective entitlements for:
- a personal account;
- an organisation;
- a user acting within an organisation context.

Example API:
- `feature_enabled?(owner, :advanced_training_planning)`
- `limit_for(owner, :included_users)`
- `subscription_for(owner)`
- `effective_features(owner)`

The resolver must:
- return FREE entitlements when no paid subscription exists;
- account for cancellation-at-period-end;
- treat `past_due`, incomplete and unpaid states according to the agreed grace policy;
- avoid granting paid access from an unverified browser return;
- handle inactive/retired plans safely;
- make personal and organisation context explicit;
- avoid N+1 database queries and cache stale entitlements safely.

### Enforcement
Use backend authorization/policy/service checks. Frontend hiding is only a UX feature and is never sufficient for access control.

### AI prompt
> Implement the subscription seed data and a central entitlement resolver. Add feature checks and quota checks for personal and organisation owners. Keep role permissions independent. Ensure FREE is the fallback and paid features are available only when the subscription is entitled under the defined status/grace rules. Add comprehensive unit tests, including users belonging to multiple organisations and switching active organisation context.

## Phase 3 — Stripe configuration and environment setup

### Stripe Dashboard
Create separate Stripe environments for test and live mode.

Create Products:
- BeachVolleyballHub Player
- BeachVolleyballHub Coach
- BeachVolleyballHub Club

Create annual recurring Prices:
- AUD 5/year
- AUD 10/year
- AUD 50/year

FREE should not require a Stripe Product or Checkout Session.

Store Stripe Price IDs in environment variables or a secure server-side configuration mapping. Do not trust a frontend-supplied Price ID or amount. The API must resolve the requested plan to its configured Stripe Price.

Recommended environment variables (names adapt to current app conventions):
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_PLAYER_YEARLY_PRICE_ID`
- `STRIPE_COACH_YEARLY_PRICE_ID`
- `STRIPE_CLUB_YEARLY_PRICE_ID`
- `STRIPE_SUCCESS_URL`
- `STRIPE_CANCEL_URL`
- `APP_FRONTEND_URL`

Use separate test and production secrets and Price IDs. Never expose the secret key or webhook signing secret to Vite/client variables.

### Webhook endpoint
Configure a dedicated HTTPS endpoint, for example:
`POST /api/v1/webhooks/stripe`

Verify the Stripe signature against the raw request body and the correct endpoint secret. Exempt only this endpoint from normal session CSRF protection as required by the Rails architecture; signature verification is mandatory.

### AI prompt
> Prepare Stripe test-mode configuration for BeachVolleyballHub. Create a server-side mapping from internal plan slugs to Stripe Price IDs, validate currency and annual recurring interval, and reject client-supplied amounts/Price IDs. Implement environment validation and safe startup diagnostics without printing secrets. Add a signed webhook endpoint using the raw request body and Stripe's official Ruby SDK. Document local Stripe CLI forwarding and staging/production setup.

## Phase 4 — Backend Checkout and billing API

Suggested endpoints (adapt to existing API naming):

Public:
- `GET /api/v1/subscriptions` — visible, active plans and feature catalogue.

Authenticated:
- `GET /api/v1/billing/status` — current owner's billing state.
- `POST /api/v1/billing/checkout` — create Checkout Session for an eligible paid plan.
- `POST /api/v1/billing/portal` — create Customer Portal session.
- `POST /api/v1/billing/change_subscription` — request upgrade/downgrade.
- `GET /api/v1/billing/history` — billing/subscription history.

Webhook:
- `POST /api/v1/webhooks/stripe`

Admin:
- CRUD for subscriptions and features.
- Assign a plan manually with an audit reason.
- Deactivate plans/features.
- Inspect subscription and webhook processing state.

### Checkout requirements
1. Authenticate the user.
2. Resolve the correct personal or organisation owner from server-side context.
3. Verify the user can manage billing for that owner.
4. Verify that the requested plan is active, visible and purchasable.
5. Verify the plan is compatible with the owner type.
6. Resolve the Price ID server-side.
7. Create or reuse the Stripe Customer associated with that owner.
8. Create Checkout Session with `mode: subscription`.
9. Include internal owner ID/type and plan ID in metadata for correlation, but do not rely on metadata alone without verifying the customer/session/price relationship.
10. Set success and cancel URLs from trusted configuration.
11. Return only the Checkout URL/session details needed by the frontend.

Use an idempotency key for repeated checkout creation where appropriate. Prevent duplicate active subscriptions for the same billable owner unless the product explicitly supports multiple concurrent subscriptions.

### Confirmation and redirect
The React success route may call a safe reconciliation/status endpoint, but it must never activate a subscription solely because `checkout=success` or a `session_id` appears in the URL.

The webhook is authoritative. A user may see a short “Payment processing” state until the webhook updates the local record.

### AI prompt
> Implement the Rails billing API for BeachVolleyballHub. Use authenticated owner context, server-side Stripe Price mapping, Customer reuse, Checkout Sessions in subscription mode, and safe return URLs. Do not accept price or amount from the browser. Add owner-specific billing authorization, duplicate-subscription protection, idempotency and request specs. Ensure the success redirect never grants entitlements by itself.

## Phase 5 — Stripe webhook lifecycle and reconciliation

### Events to support
At minimum, evaluate and handle:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.finalization_failed` where relevant

Use the Stripe API's current event payload contracts. Avoid assuming event delivery order.

### Webhook processor
Requirements:
- Verify signature before processing.
- Persist event ID and processing status.
- Enforce unique event ID/idempotency.
- Process transactionally where possible.
- Retrieve canonical Stripe objects when event payload is insufficient or stale.
- Match customer, subscription, owner and configured Price.
- Reject mismatched owner/plan/Price combinations.
- Update local subscription state.
- Record history and lifecycle audit entries.
- Handle duplicate and out-of-order delivery.
- Log failures without logging secrets or sensitive payment details.
- Return successful HTTP response only after safe receipt/persistence; use retryable processing for transient failures if an asynchronous job is used.

### State mapping
Define and test a clear mapping between Stripe and local states, for example:
- `active`
- `trialing`
- `past_due`
- `incomplete`
- `incomplete_expired`
- `unpaid`
- `canceled`
- `cancel_at_period_end`

Do not collapse all states into a simple active/cancelled boolean.

### Grace policy
Decide how long premium access remains available after failed renewal. Recommended initial policy:
- `active`: paid features enabled.
- `cancel_at_period_end`: paid features remain enabled until `current_period_end`.
- `past_due`: configurable grace period, then restricted.
- `unpaid` / `incomplete_expired`: paid features disabled.
- `canceled`: paid features disabled after effective cancellation.

The policy must be consistent across API checks, UI and scheduled reconciliation.

### Reconciliation job
Add a scheduled job to compare local billing records with Stripe:
- retrieve active and recently changed subscriptions;
- repair missed webhook updates;
- identify orphaned Stripe subscriptions;
- detect local subscriptions with missing Stripe records;
- record discrepancies and alert administrators;
- never silently grant paid access from unverified local data.

### AI prompt
> Implement a robust Stripe webhook processor and billing reconciliation job. Follow the lessons from Wine Words Issue #77 and #93. Verify signatures, persist event IDs, guarantee idempotency, tolerate duplicate/out-of-order events, verify owner/customer/subscription/Price consistency, update subscription history and audit logs, and implement the documented grace policy. Add tests for every supported event, retries, duplicate delivery, mismatched metadata and reconciliation repairs.

## Phase 6 — Subscription changes, upgrades, downgrades and cancellation

Define plan-change rules before implementing the UI.

### Recommended behaviour
- FREE → paid: Stripe Checkout.
- Player → Coach: upgrade with Stripe subscription update and documented proration.
- Coach → Player: downgrade at renewal by default.
- Paid → FREE: cancel at period end by default.
- Club changes: only an organisation billing administrator may initiate.
- Personal changes: only the personal billing owner may initiate.
- Admin override: audited and permission restricted.

### Proration
Use Stripe Billing proration rather than manually calculating card charges.

Decide:
- Whether upgrades take effect immediately.
- Whether the customer pays the prorated difference immediately.
- Whether downgrades are deferred until renewal.
- Whether billing-cycle anchors are preserved.
- What happens when payment for an upgrade fails.

Recommended initial policy:
- Upgrade: immediate, with Stripe-calculated proration and payment collection.
- Downgrade: scheduled for next renewal, no immediate loss of current paid access.
- Cancellation: at period end.
- FREE transition: at the end of the paid period.
- Failed upgrade payment: retain the prior valid entitlement until Stripe/local state confirms the change.

Never change the local plan before the corresponding Stripe operation is confirmed and reconciled.

### Renewal correctness
Persist:
- `current_period_start`
- `current_period_end`
- `cancel_at_period_end`
- `canceled_at`
- `ended_at`
- latest invoice/payment state

Use Stripe's canonical subscription state to resolve renewals.

### AI prompt
> Implement subscription plan changes for personal and organisation owners. Support immediate upgrades with Stripe proration and deferred downgrades/cancellation at period end. Prevent invalid or duplicate changes. Keep the old entitlement until the new state is confirmed. Preserve renewal dates according to the agreed policy. Record every requested and completed change in lifecycle history and audit logs. Add tests for payment failure, upgrade, downgrade, cancellation, renewal and concurrent requests.

## Phase 7 — Frontend subscription experience

### Public pricing page
Route:
- `/subscribe` or the existing equivalent.

Display:
- FREE, Player, Coach and Club cards.
- Annual AUD pricing.
- Feature list.
- User/history limits with clear wording.
- Current plan indicator for authenticated users.
- Select/upgrade/downgrade CTA according to current state.
- Clear billing period and renewal/cancellation information.

Do not hardcode prices or feature lists. Load them from the API.

### Checkout return
After Stripe redirects:
- Show a processing/success/cancelled state.
- Refresh `/me` and billing status from Rails.
- Poll or retry briefly if webhook processing is pending.
- Never activate a plan from query parameters.
- Provide a way to return to billing settings.

### Account billing page
Show:
- Current plan.
- Effective features and limits.
- Subscription status.
- Renewal date / paid-through date.
- Cancel-at-period-end status.
- Change plan.
- Manage payment method (Customer Portal).
- Billing history and invoices where available.

### Organisation billing page
For Club:
- Show organisation's current plan.
- Identify who can manage billing.
- Display organisation-level features and limits.
- Display member/seat usage if a user limit is later introduced.
- Do not expose personal billing details to other organisation members.

### Admin pages
Reuse Wine Words patterns:
- `/subscriptions` — plan catalogue management.
- Feature catalogue management.
- Add/remove/reorder features on a plan.
- Edit annual price and limits.
- Activate/deactivate plans.
- Inspect subscription owners/history.
- Manually assign a plan with mandatory reason and audit entry.
- Inspect webhook failures/reconciliation status.

### API client
Create typed/consistent API methods:
- `subscriptionsApi.list()`
- `billingApi.status(ownerContext)`
- `billingApi.checkout(planSlug, ownerContext)`
- `billingApi.portal(ownerContext)`
- `billingApi.changeSubscription(...)`
- `billingApi.history(ownerContext)`

Normalize API base URL joining to prevent duplicate slashes.

### AI prompt
> Implement the BeachVolleyballHub React subscription UI using the existing Wine Words frontend patterns. Load plans and feature data from Rails, support personal and organisation billing contexts, display annual AUD prices, handle checkout processing and refresh authoritative API state after Stripe redirects. Add billing settings, organisation billing controls and restricted admin plan management. Ensure the mobile/PWA experience is responsive and no frontend-only check is treated as authorization.

## Phase 8 — Backend feature enforcement

Create a central, reusable entitlement check and apply it to actual premium operations.

Potential examples:
- Advanced training planning.
- Advanced assessments/player development.
- Club organisation management.
- Club-level reporting.
- Any future premium features.

For every feature:
1. Identify all relevant API endpoints.
2. Identify create/read/update/delete paths.
3. Apply authorization/entitlement checks at the service or policy boundary.
4. Return a consistent error code when an entitlement is missing.
5. Keep read-only/public features available where intended.
6. Add request specs for FREE and paid owners.

Suggested error response:
- HTTP `403 Forbidden`
- stable application code such as `subscription_feature_required`
- required plan/feature metadata suitable for the frontend upgrade prompt.

Do not rely on React route guards alone.

### AI prompt
> Audit BeachVolleyballHub API endpoints and map each proposed premium feature to its backend operations. Implement entitlement enforcement in policies/services, not only controllers or React. Keep role authorization separate. Return consistent 403 responses with stable error codes. Add request specs proving FREE users cannot bypass restrictions by calling endpoints directly and that eligible personal/organisation subscriptions work in the correct context.

## Phase 9 — Usage limits and history

Even though current plan limits are zero, build a reusable limit framework now.

Potential future limits:
- Organisation seats.
- Active coaches.
- Player profiles managed by a club.
- Training sessions.
- Assessment history retention.
- Video storage.
- Analysis records.

Requirements:
- Define quota unit and counting scope.
- Decide whether deleted/archived records count.
- Decide whether historical data is hidden, read-only or deleted after downgrade.
- Never destructively delete user data automatically on downgrade.
- Prefer read-only access or export for data exceeding a downgraded limit.
- Make limit checks transaction-safe to avoid race conditions.
- Provide usage summaries to the UI.

Do not implement arbitrary limits until product definitions are approved.

### AI prompt
> Implement a generic subscription quota service for BeachVolleyballHub. Support nullable/unlimited values and explicit zero semantics. Make quotas owner-scoped and transaction-safe. Do not delete records when a user downgrades. Provide usage summaries and consistent limit-exceeded API responses. Add tests for concurrency, upgrades, downgrades and historical records.

## Phase 10 — Security, reliability and observability

### Security
- Keep Stripe secret keys and webhook secrets server-side only.
- Verify Stripe webhook signatures using the raw request body.
- Enforce authorization on all billing endpoints.
- Verify the caller controls the personal or organisation billing owner.
- Never accept arbitrary owner IDs without membership/permission checks.
- Never trust browser success URLs as proof of payment.
- Never trust frontend-supplied amounts, currency or Price IDs.
- Validate allowed redirect URLs.
- Rate-limit checkout and portal session creation.
- Use idempotency keys.
- Prevent duplicate subscriptions and concurrent plan changes.
- Avoid logging payment details, secrets or unnecessary personal information.
- Apply least privilege to admin billing operations.
- Audit manual assignments and plan changes.

### Cloudflare and API protection
Use existing Cloudflare protections where applicable:
- WAF/rate limiting for public and authenticated billing endpoints.
- Protect webhook endpoint from generic bot challenges that could block Stripe.
- Do not require Turnstile on Stripe's server-to-server webhook.
- If Turnstile is used on checkout initiation, verify the token server-side and do not treat it as authentication.
- Ensure Cloudflare rules do not cache billing/status responses or webhook requests.

### Reliability
- Webhook event persistence and idempotency.
- Background retries for transient failures.
- Scheduled reconciliation.
- Alert on repeated webhook processing failures.
- Alert on subscription/customer/Price mismatches.
- Keep local entitlement reads fast and predictable.

### Observability
Log structured events for:
- Checkout Session created.
- Customer created/reused.
- Stripe webhook received.
- Signature verification failed.
- Event duplicate detected.
- Subscription activated/updated/cancelled.
- Invoice paid/payment failed.
- Plan change requested/completed/failed.
- Reconciliation mismatch/repaired.
- Manual admin assignment.

Include owner type/id, local subscription id, Stripe IDs and correlation/request ID where safe. Never log secrets or card data.

### AI prompt
> Review the Stripe integration for security and operational readiness. Add authorization, owner-scoped billing permissions, rate limiting, webhook signature verification, idempotency, audit logging, safe error handling, reconciliation monitoring and Cloudflare compatibility. Ensure Cloudflare bot challenges never block Stripe webhooks. Add security tests for IDOR, forged owner IDs, untrusted Price IDs, replayed events and unauthorized organisation billing actions.

## Phase 11 — Testing and acceptance

### API model/service tests
- Exactly one default FREE plan.
- Correct annual prices and AUD currency.
- Feature associations and ordering.
- Plan deactivation and delete guards.
- Personal versus organisation ownership.
- FREE fallback.
- Feature resolver behaviour.
- Quota zero/null semantics.
- Role permissions unaffected by subscription changes.

### Billing tests
- Checkout session creation.
- Server-side Price ID resolution.
- Existing Stripe Customer reuse.
- Duplicate checkout prevention.
- Webhook signature verification.
- Duplicate webhook delivery.
- Out-of-order webhook events.
- Successful initial payment.
- Failed initial payment.
- Successful renewal.
- Failed renewal and grace policy.
- Cancellation at period end.
- Upgrade proration.
- Deferred downgrade.
- Reconciliation repair.
- Owner/Customer/Price mismatch rejection.

Use Stripe test mode and Stripe CLI for local webhook forwarding. Use test cards and Stripe's documented test scenarios, including authentication-required payment flows.

### Frontend tests
- Pricing page loads API data.
- Correct current-plan display.
- Checkout redirect.
- Checkout pending state.
- Cancelled checkout.
- Webhook delay and refresh.
- Customer Portal redirect.
- Plan-change states.
- Personal versus organisation billing.
- Admin-only controls.
- Mobile and PWA layout.

### End-to-end acceptance flow
1. Register a new user.
2. Confirm FREE is assigned automatically.
3. Open pricing page.
4. Choose Player.
5. Create Stripe Checkout Session.
6. Complete Stripe test payment.
7. Stripe webhook is received and verified.
8. Local subscription becomes active.
9. API returns Player entitlements.
10. React refreshes and displays Player.
11. Upgrade to Coach and verify proration/state.
12. Schedule downgrade and verify paid access remains until renewal.
13. Cancel and verify effective cancellation.
14. Verify FREE entitlements after the paid period ends.
15. Repeat with an organisation and Club subscription.
16. Verify a member without billing permission cannot manage the Club subscription.
17. Verify a personal subscription does not change the Club subscription.

### AI prompt
> Run a full subscription acceptance audit across BeachVolleyballHub API and frontend. Execute migrations, seeds, Rails tests, frontend lint/build and end-to-end billing tests in Stripe test mode. Verify webhook idempotency, renewal and plan-change behaviour, organisation billing permissions, mobile/PWA layout and direct API entitlement enforcement. Report failures with exact file references and do not mark the implementation complete until all critical billing lifecycle cases pass.

## Phase 12 — Documentation and production launch

Create documentation in the API repository, for example:

`docs/subscriptions/`
- `README.md`
- `architecture.md`
- `plans-and-features.md`
- `stripe-configuration.md`
- `webhooks.md`
- `subscription-lifecycle.md`
- `admin-guide.md`
- `testing.md`
- `production-deployment.md`
- `troubleshooting.md`

Document:
- Stripe Products and annual Prices.
- Test/live environment setup.
- Required Render environment variables.
- Webhook endpoint and subscribed event types.
- Stripe CLI local development.
- Customer Portal configuration.
- Plan and feature administration.
- Subscription state mapping.
- Grace and cancellation policy.
- Reconciliation process.
- Refunds and disputes operational handling.
- Deployment/rollback steps.

### Production checklist
- [ ] Confirm AUD prices and annual billing.
- [ ] Confirm zero/null semantics for Users and History.
- [ ] Approve feature catalogue and plan mappings.
- [ ] Confirm personal and Club billing ownership.
- [ ] Create Stripe live Products and Prices.
- [ ] Configure live API and webhook secrets in Render.
- [ ] Configure webhook endpoint in Stripe.
- [ ] Verify webhook delivery in production.
- [ ] Verify success/cancel URLs and custom domain.
- [ ] Verify Customer Portal.
- [ ] Verify Cloudflare rules.
- [ ] Run a real low-value controlled transaction if appropriate.
- [ ] Confirm receipts and customer-facing billing details.
- [ ] Confirm support and refund process.
- [ ] Enable reconciliation schedule and monitoring.
- [ ] Keep a rollback and manual reconciliation procedure.

### AI prompt
> Prepare production deployment documentation for BeachVolleyballHub subscriptions. Document Stripe live-mode setup, Render environment variables, webhook configuration, Customer Portal, Cloudflare rules, pricing/feature administration, monitoring, reconciliation, refunds and rollback. Do not expose credentials. Provide a pre-launch checklist and post-deployment verification steps.

---

## 5. Suggested implementation order

| Order | Phase | Main outcome |
|---:|---|---|
| 1 | Phase 0 | Repository audit and decisions |
| 2 | Phase 1 | Data model |
| 3 | Phase 2 | Plans, features and entitlements |
| 4 | Phase 3 | Stripe configuration |
| 5 | Phase 4 | Checkout and billing API |
| 6 | Phase 5 | Webhooks and reconciliation |
| 7 | Phase 6 | Upgrades, downgrades and cancellation |
| 8 | Phase 7 | Frontend billing experience |
| 9 | Phase 8 | Backend feature enforcement |
| 10 | Phase 9 | Usage limits and history |
| 11 | Phase 10 | Security and observability |
| 12 | Phase 11 | Testing and acceptance |
| 13 | Phase 12 | Documentation and production launch |

Some phases can be developed in parallel after the data contracts are agreed, but webhook correctness and backend entitlement enforcement must not be postponed until after launch.

## 6. Key architecture recommendations

1. **Reuse Wine Words' subscription catalogue and feature catalogue.** Adapt rather than duplicate.
2. **Use Stripe Billing + Checkout + Customer Portal.** Do not implement recurring charges with manual PaymentIntents.
3. **Webhook is the authority.** Browser redirects never activate subscriptions.
4. **Support personal and organisation billing owners.** Club is an organisation subscription.
5. **Do not couple paid plans to volleyball roles.** A Coach remains a Coach even when on FREE.
6. **Centralise entitlement checks.** All backend feature checks use one resolver/service.
7. **Keep subscription history.** Deactivate old plans; do not destroy billing records.
8. **Use Stripe Price IDs as configuration.** Do not hardcode amounts in application code or trust client input.
9. **Treat plan changes as a lifecycle.** Proration, renewal, failed payments and cancellation must be tested.
10. **Preserve data on downgrade.** Restrict premium operations rather than deleting user content.
11. **Make the UI owner-aware.** Personal billing and Club billing are distinct contexts.
12. **Document operations.** Production billing requires webhook monitoring and reconciliation.

## 7. Decisions required before implementation

The following questions should be resolved in Phase 0:

1. Are all prices AUD and inclusive or exclusive of applicable taxes?
2. Does `Users = 0` mean zero additional users, unlimited, or not applicable?
3. Does `History = 0` mean no history retention, unlimited, or not applicable?
4. Is the Club plan intended to include a number of member/coach seats? If yes, what is the initial allowance?
5. Which exact five features should Club include, and which three should Coach include?
6. Can a user have Player and Coach personal subscriptions simultaneously, or must they select one personal plan at a time?
7. Can an organisation have multiple Club subscriptions, or only one active subscription?
8. Should Club billing be managed only by organisation owners/admins?
9. Should cancellation and downgrades take effect at the end of the annual period? Recommended: yes.
10. What grace period should apply after a failed renewal?

## 8. Definition of done

The implementation is complete when:

- FREE is assigned automatically to new eligible accounts.
- Player, Coach and Club annual plans are configurable.
- Stripe Checkout successfully creates paid subscriptions.
- Signed Stripe webhooks activate and update subscriptions idempotently.
- Renewal, failed payment, cancellation, upgrade and downgrade flows work.
- Personal and organisation billing are isolated correctly.
- API endpoints enforce entitlements independently of the frontend.
- Roles remain independent of subscription state.
- Admins can manage plans/features and inspect subscription history.
- Customer Portal works for the correct billing owner.
- Subscription history and audit logs are retained.
- Tests cover security, webhook lifecycle, entitlements and organisation permissions.
- Documentation and production deployment configuration are complete.

---

## 9. Source references

- Wine Words API: https://github.com/romalopes/wine_words_api
- Wine Words frontend: https://github.com/romalopes/wine_words_front_end
- Wine Words subscription architecture, Issue #22: https://github.com/romalopes/wine_words_api/issues/22
- Stripe payment flow, Issue #77: https://github.com/romalopes/wine_words_api/issues/77
- Subscription downgrade/upgrade, Issue #73: https://github.com/romalopes/wine_words_api/issues/73
- Partial payment on upgrade, Issue #80: https://github.com/romalopes/wine_words_api/issues/80

---

# 10. Implementation status — 14 November 2026

**Status:** implemented in `beachvolleyballhub_api` and `beachvolleyballhub`. Nothing
has been committed; the working trees contain the changes.

Per-phase records with files, decisions and verification commands:
[phase 0](phase-00-audit.md) · [1](phase-01-data-model.md) ·
[2](phase-02-seeds-entitlements.md) · [3](phase-03-stripe-configuration.md) ·
[4](phase-04-checkout-billing-api.md) · [5](phase-05-webhooks-reconciliation.md) ·
[6](phase-06-lifecycle-changes.md) · [7](phase-07-frontend.md) ·
[8](phase-08-backend-enforcement.md) · [9](phase-09-quotas.md) ·
[10](phase-10-security-reliability.md) · [11](phase-11-testing.md) ·
[12](phase-12-documentation-launch.md)

Operational documentation: [`../subscriptions/`](../subscriptions/README.md).

## 10.1 Phase outcomes

| Phase | Outcome |
|---|---|
| 0 Audit | Account/Organisation ownership confirmed; no existing billing code; decisions recorded |
| 1 Data model | 7 tables; catalogue, customers, current state, checkout, history, webhook ledger |
| 2 Seeds/entitlements | Idempotent seeds; central `Entitlements::Resolver` with status policy |
| 3 Stripe config | Server-side keys/Price mapping, Price validation, safe diagnostics |
| 4 Checkout/API | Owner-scoped billing endpoints, public catalogue, admin catalogue/assignment |
| 5 Webhooks | Signed, idempotent, correlated, order-tolerant; daily reconciliation |
| 6 Lifecycle | Immediate prorated upgrades, renewal-scheduled downgrades, period-end cancellation |
| 7 Frontend | Pricing, personal billing, club billing, checkout return, admin catalogue |
| 8 Enforcement | Feature checks at the API boundary, opt-in per environment |
| 9 Quotas | Explicit null/zero/positive semantics; no unapproved limits enforced |
| 10 Security | Owner authorization, rate limits, webhook safelist, audit logging |
| 11 Testing | 82 billing-focused tests passing; full suite has two pre-existing failures |
| 12 Documentation | 13 operational docs + 13 phase records |

## 10.2 Billable owner (answer to §3.2)

A polymorphic `billable` restricted to `Account` and `Organisation`, not a new
account system and not `users.subscription_id`. `billing_customers` and
`billing_subscriptions` are unique per owner, so one Club has one Customer even
with several administrators, and a personal Customer is never reused for a club.

## 10.3 Limits (answer to §3.1 and §7)

`NULL` = unlimited/not applicable; `0` = none beyond documented owner access;
positive = explicit quota. The launched catalogue uses `0` for both limits, so the
owner has access but no extra seats and no extended retention. `0` is never treated
as unlimited.

## 10.4 Feature enforcement mapping

| Feature | Enforced on | Context |
|---|---|---|
| `enhanced_player_profile` | Catalogue/display only in this release | personal |
| `advanced_training_planning` | training templates + recurring series mutations | personal |
| `advanced_assessments` | assessment session create/update/publish/restore | personal |
| `organisation_management` | organisation update/archive/restore/logo | organisation |
| `club_reporting` | organisation coaches listing | organisation |

Enforcement is gated by `BILLING_ENFORCEMENT_ENABLED` and bypassed for
admin/curator oversight. Role authorization is unchanged and runs first.

## 10.5 Configuration required (not stored in the repository)

API process: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`STRIPE_PLAYER_YEARLY_PRICE_ID`, `STRIPE_COACH_YEARLY_PRICE_ID`,
`STRIPE_CLUB_YEARLY_PRICE_ID`, `APP_FRONTEND_URL`; optional
`STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`, `STRIPE_PORTAL_RETURN_URL`,
`BILLING_GRACE_PERIOD_DAYS` (default 7), `BILLING_ENFORCEMENT_ENABLED`,
`STRIPE_PUBLISHABLE_KEY`.

Integrations: Stripe Products/Prices (AUD, annual), one webhook endpoint with nine
events, Customer Portal; Cloudflare must allow and not cache the webhook; Render
must expose the same variables to the web worker and the Solid Queue worker (daily
reconciliation).

## 10.6 Deviations from the proposal

- The public catalogue omits Stripe Price IDs entirely instead of exposing them to
  the SPA; only `stripe_price_configured` is returned.
- A `stripe_price_id` column exists as an admin fallback, but environment variables
  take precedence so test/live cannot cross over.
- Downgrades use Stripe Subscription Schedules rather than a locally applied
  pending plan.
- The return page polls `/billing/status`; no `session_id` confirmation endpoint was
  added, because it would duplicate the webhook's authority.
- Enforcement is opt-in per environment because the premium operations already
  existed before billing; turning it on is a deployment decision.

## 10.7 Verification

```bash
cd beachvolleyballhub_api
bin/rails db:migrate && bin/rails db:seed && bin/rails zeitwerk:check
bin/rails test test/models/subscription_test.rb test/services/entitlements \
  test/services/billing test/controllers/api/v1/billing_controller_test.rb \
  test/controllers/api/v1/subscriptions_controller_test.rb \
  test/controllers/api/v1/webhooks_stripe_controller_test.rb \
  test/controllers/api/v1/admin/subscriptions_controller_test.rb \
  test/controllers/api/v1/subscription_enforcement_test.rb
```

```bash
cd beachvolleyballhub
npx tsc -b && npm run lint
npx vitest run src/pages/Subscribe.test.tsx src/pages/Billing.test.tsx
```
- Unified subscription lifecycle, Issue #93: https://github.com/romalopes/wine_words_api/issues/93
- Stripe Billing subscription samples: https://github.com/stripe-samples/subscription-use-cases
- Stripe Checkout subscription sample: https://github.com/stripe-samples/checkout-single-subscription
