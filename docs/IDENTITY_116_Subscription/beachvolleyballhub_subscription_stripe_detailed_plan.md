# BeachVolleyballHub — Detailed Subscription & Stripe Implementation Plan
## Expanded engineering specification with phase-by-phase AI prompts

**Document status:** Proposed implementation specification  
**Prepared:** 14 November 2026  
**Primary repositories:**
- API: https://github.com/romalopes/beachvolleyballhub_api
- Frontend: https://github.com/romalopes/beachvolleyballhub_frontend

**Reference repositories:**
- Wine Words API: https://github.com/romalopes/wine_words_api
- Wine Words frontend: https://github.com/romalopes/wine_words_front_end

**Primary reference issue:**
- Wine Words subscription architecture: https://github.com/romalopes/wine_words_api/issues/22

**Related reference issues to inspect:**
- Stripe checkout/payment flow: https://github.com/romalopes/wine_words_api/issues/77
- Subscription upgrade/downgrade rules: https://github.com/romalopes/wine_words_api/issues/73
- Upgrade proration/partial payment: https://github.com/romalopes/wine_words_api/issues/80
- Unified subscription lifecycle and renewal handling: https://github.com/romalopes/wine_words_api/issues/93

---

# 1. Purpose and implementation principles

Implement a complete subscription and recurring-payment system for BeachVolleyballHub using Stripe Billing.

Wine Words is the architectural reference. The goal is to reuse its proven patterns and lessons, not blindly copy code. BeachVolleyballHub has a different domain model because it supports individual volleyball users and organisations/clubs.

The implementation must provide:

1. A configurable subscription-plan catalogue.
2. A configurable feature catalogue.
3. Annual recurring payments through Stripe.
4. Automatic assignment of the default FREE plan.
5. Personal subscriptions for Player and Coach.
6. Organisation-owned subscriptions for Club.
7. Subscription history and lifecycle audit records.
8. Stripe Checkout for new paid subscriptions.
9. Stripe Customer Portal for self-service billing.
10. Signed, idempotent Stripe webhooks.
11. Upgrade, downgrade, renewal, cancellation and failed-payment handling.
12. Central backend entitlement and quota enforcement.
13. Frontend pricing, account billing and organisation billing pages.
14. Administration interfaces for plans, features and billing support.
15. Automated tests, operational monitoring and deployment documentation.

## 1.1 Non-negotiable principles

- The Stripe webhook, not the browser redirect, is authoritative for payment state.
- A user role is not a subscription entitlement.
- A subscription plan does not replace existing Account, Person, PlayerProfile, CoachProfile or Organisation concepts.
- Personal and organisation subscriptions must be isolated.
- All paid access must be enforced by the API.
- The frontend may hide unavailable actions but cannot be the security boundary.
- Never trust a browser-supplied price, currency, Stripe Price ID or owner ID.
- Never store card numbers or CVC values.
- Never delete customer data automatically when a subscription is downgraded.
- Subscription history and billing audit records must be retained.
- Webhook processing must be idempotent and resilient to duplicate/out-of-order events.
- Plan and feature catalogues must be configurable without code changes for ordinary catalogue updates.

## 1.2 Repository working rules for AI coding agents

Apply these rules in every implementation phase:

1. Inspect both repositories before modifying code.
2. Read the relevant Wine Words implementation and related issue history before designing an equivalent feature.
3. Follow current BeachVolleyballHub conventions unless there is a documented reason to change them.
4. Do not replace or refactor unrelated authentication, role, Account or organisation architecture.
5. Do not introduce a second billing/account abstraction if an existing model can safely support the requirement.
6. Keep migrations reversible.
7. Add or update tests with each implementation change.
8. Run relevant tests, linting and builds before finishing a phase.
9. Do not silently change API contracts. Document frontend/backend contract changes.
10. Do not invent Stripe IDs, secrets, environment values or production configuration.
11. Do not mark a phase complete when tests have not been run.
12. At the end of each phase, report files changed, migrations, tests run, test results, unresolved decisions and follow-up work.

---

# 2. Subscription catalogue

The requested annual plans are:

| Plan | Annual price | Default | Users | History | Features |
|---|---:|:---:|---:|---:|---:|
| FREE | $0 | Yes | 0 | 0 | 0 |
| Player | $5 | No | 0 | 0 | 1 |
| Coach | $10 | No | 0 | 0 | 3 |
| Club | $50 | No | 0 | 0 | 5 |

Assume AUD unless confirmed otherwise. Store prices in integer cents:
- FREE: `0`
- Player: `500`
- Coach: `1000`
- Club: `5000`

All paid plans are annual recurring prices. FREE is not a Stripe subscription and must not require Checkout.

## 2.1 Define Users and History carefully

The requested table sets Users and History to zero for every plan. The implementation must not guess what zero means.

Agree on explicit semantics before enforcement:
- `0`: zero allowance.
- `nil`: unlimited or not limited by this dimension.
- Positive integer: exact allowance.

For example, if Users means additional seats, define whether the primary account owner is excluded from the count. If Club eventually includes seats, count membership records according to a documented status policy (e.g. active members only).

For History, define the unit:
- number of records;
- months of history;
- years of history;
- or a feature-specific retention policy.

Do not implement destructive data deletion when history limits are exceeded. Prefer read-only access, restricted creation, archive/export or a clear upgrade prompt.

## 2.2 Feature catalogue proposal

The feature counts are catalogue-entry counts. They are not numeric feature flags.

Initial proposal, to be confirmed:

| Feature | Player | Coach | Club |
|---|:---:|:---:|:---:|
| Enhanced personal player profile | ✓ | ✓ | ✓ |
| Advanced training planning | | ✓ | ✓ |
| Advanced assessments and player development | | ✓ | ✓ |
| Organisation management | | | ✓ |
| Club-level reporting and management | | | ✓ |

This is a starting proposal only. The catalogue must be editable by administrators.

## 2.3 Roles versus subscriptions

Keep these separate:

- Roles: Player, Coach, Admin, Curator, organisation-specific roles and other existing permissions.
- Features: capabilities granted by a subscription.
- Limits: quantities/quotas associated with a subscription.
- Subscription state: current billing entitlement.

A person can be a Coach while subscribed to FREE. They retain their Coach identity and basic permissions but cannot use paid Coach features.

Never remove Admin or Curator privileges because a subscription changes.

---

# 3. Billing ownership model

BeachVolleyballHub must support two billing contexts.

## 3.1 Personal billing

- FREE: default personal plan.
- Player: personal paid plan.
- Coach: personal paid plan.

A personal subscription belongs to the user's personal Account (or the equivalent existing personal billable owner), not to a volleyball profile unless the audit proves that profile is the correct stable owner.

## 3.2 Organisation billing

- Club: organisation-owned plan.

Only an organisation owner or an explicitly authorised billing administrator may:
- start Club Checkout;
- open the Club Customer Portal;
- change the Club plan;
- cancel Club billing;
- view organisation invoices and billing history.

Ordinary organisation members must not be able to see payment details or change billing.

## 3.3 Concurrent contexts

A Coach may have a personal Coach plan and be a member of a Club with a Club plan. These subscriptions are independent.

The entitlement resolver must require explicit context:
- personal context;
- selected organisation context.

Do not silently merge all entitlements into one global user plan. A Club plan grants organisation features while the user is acting within that organisation; it must not grant unrelated personal features.

## 3.4 Owner model decision

During Phase 0 inspect whether the existing `Account` model already represents both personal and organisation ownership. Prefer that existing abstraction if it is safe and consistent.

If it cannot represent both, use a deliberate billable-owner design. A polymorphic owner can work, but it must have:
- an explicit allowlist of owner types;
- ownership validation;
- database constraints where practical;
- authorization checks on every operation;
- no client-controlled owner type/id pair without server verification.

---

# 4. Phase 0 — Repository audit and decisions

## Objective

Understand the current BeachVolleyballHub architecture and the exact Wine Words implementation before coding.

## API audit checklist

Inspect:
- Rails and Ruby versions.
- Gemfile and Stripe-related gems, if any.
- User and authentication models.
- Account, Person, PlayerProfile and CoachProfile.
- Organisation and membership models.
- Roles, permissions and policy framework.
- Existing billing/subscription code.
- API namespace and serializer conventions.
- Database migrations, indexes and constraints.
- Background jobs and scheduler.
- Audit logging and notification mechanisms.
- Environment variable conventions.
- Render deployment and database configuration.
- Existing request/model/service test patterns.

## Frontend audit checklist

Inspect:
- React/Vite versions and project structure.
- Router and protected route patterns.
- Authentication/current-user state.
- API client and base URL handling.
- Account/profile settings.
- Organisation management/settings.
- Role-aware navigation.
- UI library and form conventions.
- Error/loading/notification handling.
- Existing pricing/billing pages.
- Responsive and PWA navigation.

## Wine Words audit checklist

Inspect Issue #22 and the implementation files for:
- subscription catalogue;
- feature catalogue;
- plan-feature join model;
- user subscription/history;
- default FREE assignment;
- admin CRUD;
- pricing UI;
- Stripe checkout;
- webhook processor;
- plan changes;
- proration;
- renewal and cancellation;
- tests and deployment configuration.

Do not assume issue descriptions exactly match current code. Verify the repository state.

## Deliverables

- Architecture decision record (ADR).
- Existing-to-new model mapping.
- Proposed API contracts.
- List of code patterns reusable from Wine Words.
- Confirmed meaning of Users and History.
- Confirmed feature names and mappings.
- Confirmed personal/organisation billing permissions.
- List of outstanding product decisions.

### AI prompt — Phase 0: Audit only

```text
You are auditing the BeachVolleyballHub application before implementing subscriptions.

Repositories:
- API: https://github.com/romalopes/beachvolleyballhub_api
- Frontend: https://github.com/romalopes/beachvolleyballhub_frontend
- Reference API: https://github.com/romalopes/wine_words_api
- Reference frontend: https://github.com/romalopes/wine_words_front_end

Reference issue:
- https://github.com/romalopes/wine_words_api/issues/22

Also inspect related Wine Words issues:
- #77 Stripe payment flow and webhook activation
- #73 upgrade/downgrade rules
- #80 proration/partial payment on upgrade
- #93 lifecycle, renewal and reconciliation

Do not modify any files.

1. Inspect the current BeachVolleyballHub API and frontend architecture.
2. Identify the exact models for User, Account, Person, PlayerProfile, CoachProfile, Organisation and memberships.
3. Identify how roles and permissions are represented and enforced.
4. Inspect authentication, current-user context, API response conventions and frontend route guards.
5. Inspect background jobs, scheduled jobs, audit logging and tests.
6. Inspect the Wine Words implementation and identify the actual reusable classes, migrations, services, controllers, routes, React components and tests.
7. Compare the two projects and explain which Wine Words patterns can be reused and which must change.
8. Recommend a billable-owner design supporting personal Player/Coach plans and organisation-owned Club plans.
9. Explain how personal and organisation entitlements must remain independent.
10. Identify risks, missing requirements and product decisions.

Output:
- Architecture summary.
- Existing model relationship diagrams (Mermaid is acceptable).
- Proposed subscription architecture.
- Proposed API endpoint list.
- Proposed database entities and relationships.
- File-by-file implementation map.
- Product decisions requiring confirmation.
- Phased implementation recommendations.

Do not guess file names. Cite actual repository paths and relevant code.
```

### Acceptance criteria

- No code changed.
- Audit covers both repositories.
- Wine Words implementation is verified against actual code.
- Personal and organisation billing model is explicit.
- Unresolved product decisions are documented.

---

# 5. Phase 1 — Database schema and models

## Objective

Create the catalogue, owner subscription, Stripe mapping and immutable history structures.

## Suggested entities

Adapt naming to the existing codebase. Do not create duplicate concepts if equivalents already exist.

### `subscriptions` — plan catalogue

Suggested fields:
- `name`
- `slug` (unique)
- `description`
- `active`
- `visible`
- `is_default`
- `position`
- `currency` (AUD)
- `yearly_price_cents`
- `included_users` (nullable)
- `history_limit` (nullable)
- supported owner categories, if needed
- timestamps

Constraints:
- unique slug;
- non-negative price;
- valid currency;
- one default plan;
- FREE is the only default plan;
- paid plans have a valid annual price.

### `subscription_features`

Suggested fields:
- `name`
- `slug` (unique)
- `description`
- `active`
- `position`
- timestamps

### `subscription_subscription_features`

Suggested fields:
- `subscription_id`
- `subscription_feature_id`
- `position`
- timestamps if consistent with conventions

Add a unique composite index.

### Current owner subscription

The actual design depends on Phase 0. It must identify:
- billable owner;
- selected plan;
- local status;
- Stripe Customer ID;
- Stripe Subscription ID;
- Stripe Price ID;
- current billing period start/end;
- cancel-at-period-end;
- canceled/ended timestamps;
- trial fields if trials are approved;
- last synchronized timestamp.

Do not store sensitive card details.

### `subscription_histories`

Record lifecycle transitions:
- billable owner;
- plan;
- old/new plan where applicable;
- local status;
- source (`checkout`, `webhook`, `admin`, `migration`, etc.);
- effective start/end;
- Stripe identifiers;
- cancellation/change timestamps;
- safe metadata;
- created timestamp.

History should be append-only or treated as immutable except for carefully controlled corrections.

### `billing_events`

Store webhook event processing information:
- Stripe event ID (unique);
- event type;
- Stripe object ID;
- received timestamp;
- processed timestamp;
- processing status;
- retry/error summary;
- safe payload metadata or a carefully controlled payload representation.

Do not store unnecessary personal or payment information.

## Migration and model requirements

- Foreign keys and indexes.
- Unique constraints.
- Validations.
- Reversible migrations.
- Safe handling of existing accounts.
- No accidental default-plan duplication.
- Plan deactivation rather than destructive deletion.
- Model tests for ownership and associations.

### AI prompt — Phase 1: Schema and models

```text
Implement Phase 1 of BeachVolleyballHub subscriptions.

First re-check the Phase 0 architecture decision record and the current model relationships. Do not assume the proposed names are mandatory; follow existing project conventions.

Requirements:
1. Create or adapt the subscription plan catalogue.
2. Create or adapt the feature catalogue.
3. Create the plan-feature many-to-many association with ordering.
4. Implement a current subscription/billing record for the approved billable-owner model.
5. Support personal and organisation-owned subscriptions without duplicating Account or Organisation models.
6. Create immutable subscription lifecycle history.
7. Create webhook event/idempotency persistence.
8. Store all money as integer cents and currency as an explicit ISO currency code.
9. Add Stripe IDs only where required; never store card details.
10. Add foreign keys, unique indexes, database constraints and model validations.
11. Enforce one default FREE plan.
12. Prevent hard deletion of plans/features with historical or active references; use deactivation.
13. Make migrations reversible and safe for existing production data.

Testing:
- model associations;
- owner-type validation;
- unique slug;
- default-plan constraints;
- price validation;
- duplicate join prevention;
- history retention;
- deletion/deactivation rules;
- migration rollback.

Do not implement Stripe Checkout or frontend code in this phase.

At completion, report every migration/model/spec changed and the exact test commands/results.
```

### Acceptance criteria

- Migrations apply and roll back.
- Database constraints protect critical invariants.
- Personal and organisation owners are supported.
- History and billing events are persisted safely.
- Existing authentication and role models remain intact.

---

# 6. Phase 2 — Seed plans, features and entitlement resolver

## Objective

Seed the four plans and implement a central backend entitlement resolver.

## Seed data

| Slug | Name | Annual cents | Default | Features |
|---|---|---:|:---:|---:|
| `free` | FREE | 0 | Yes | 0 |
| `player` | Player | 500 | No | 1 |
| `coach` | Coach | 1000 | No | 3 |
| `club` | Club | 5000 | No | 5 |

Seed feature records only after the product approves their exact names and mapping.

Seeds must be idempotent. Re-running seeds must not create duplicates or reset administrator-managed content without an explicit policy.

## Entitlement resolver

Create a central service, for example:
- `Entitlements::Resolver`
- `Entitlements::FeatureAccess`
- `Entitlements::LimitChecker`

Possible operations:
- `plan_for(owner, context:)`
- `feature_enabled?(owner, feature_slug, context:)`
- `limit_for(owner, limit_name, context:)`
- `usage_for(owner, limit_name, context:)`
- `allowed?(owner, action, context:)`

The resolver must:
- default to FREE;
- distinguish personal and organisation context;
- consider subscription lifecycle status and period end;
- implement the approved failed-payment grace policy;
- never grant access from a browser redirect;
- avoid N+1 queries;
- handle inactive plans;
- have predictable caching/invalidation behaviour.

## Status policy

Document exact entitlement behaviour for:
- `active`
- `trialing` if enabled
- `past_due`
- `incomplete`
- `incomplete_expired`
- `unpaid`
- `canceled`
- cancel-at-period-end

### AI prompt — Phase 2: Seeds and entitlements

```text
Implement Phase 2 using the approved Phase 0 and Phase 1 decisions.

1. Add idempotent seed data for FREE, Player, Coach and Club.
2. Use annual AUD prices of 0, 500, 1000 and 5000 cents respectively.
3. FREE must be the sole default plan.
4. Seed the approved feature catalogue and plan-feature associations.
5. Do not invent feature names if the product mapping has not been approved. Mark the mapping as a blocking decision instead.
6. Implement a central entitlement resolver for personal and organisation owners.
7. Require explicit context when resolving organisation entitlements.
8. Implement the documented Stripe/local subscription status policy.
9. Treat zero and nil limits according to the approved semantics.
10. Keep role authorization separate from subscription entitlements.
11. Ensure FREE fallback for accounts without a paid subscription.
12. Implement cache invalidation or avoid caching until correctness is established.

Add tests for:
- every plan and feature mapping;
- default FREE;
- no subscription;
- active paid subscription;
- cancel-at-period-end;
- past_due and grace period;
- canceled/expired/unpaid;
- inactive plan;
- personal vs organisation context;
- user belonging to multiple organisations;
- zero and nil limit behaviour.

Do not implement Stripe API calls in this phase.
```

### Acceptance criteria

- Seed task is safe to run repeatedly.
- FREE fallback works.
- Resolver is the single source of truth for feature entitlement.
- Organisation context cannot accidentally grant personal entitlements.

---

# 7. Phase 3 — Stripe products, prices and environment configuration

## Objective

Configure Stripe Billing safely for test and production.

## Stripe Dashboard setup

Create separate test-mode and live-mode products:

- BeachVolleyballHub Player
- BeachVolleyballHub Coach
- BeachVolleyballHub Club

Create annual recurring prices:
- AUD 5/year
- AUD 10/year
- AUD 50/year

Do not create a Stripe subscription for FREE.

Use current Stripe Products and Prices, not legacy Plans.

## Server-side configuration

Suggested environment variables (adapt to current conventions):

```bash
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=

STRIPE_PLAYER_YEARLY_PRICE_ID=
STRIPE_COACH_YEARLY_PRICE_ID=
STRIPE_CLUB_YEARLY_PRICE_ID=

STRIPE_SUCCESS_URL=
STRIPE_CANCEL_URL=
APP_FRONTEND_URL=
```

Only the publishable key may be exposed to the frontend. Secret and webhook keys must remain server-side.

The backend maps internal plan slugs to configured Stripe Price IDs. The client sends a plan slug, never an amount or Stripe Price ID.

## Local development

Use Stripe CLI to forward test webhook events to the local API. Document:
- login;
- listen/forward command;
- webhook signing secret;
- trigger commands;
- test event inspection.

Do not put real secrets in source control, documentation examples or logs.

### AI prompt — Phase 3: Stripe configuration

```text
Implement the Stripe configuration layer for BeachVolleyballHub.

1. Use the official Stripe Ruby SDK compatible with the current Rails/Ruby versions.
2. Add a single server-side configuration service mapping:
   - player -> Player annual Price ID
   - coach -> Coach annual Price ID
   - club -> Club annual Price ID
3. FREE must not map to a Stripe Price.
4. Validate that configured Prices belong to the expected Stripe Product, use AUD and recur annually.
5. Never accept a client-provided amount, currency or Price ID.
6. Validate required environment variables in a safe manner.
7. Never print secret values in logs or exception messages.
8. Keep test and live credentials separate.
9. Document local Stripe CLI webhook forwarding.
10. Add unit tests for missing, malformed and mismatched configuration.

Do not create live Stripe resources or assume production credentials exist. Do not expose secret values through Vite environment variables.
```

### Acceptance criteria

- Test and live configurations are distinct.
- Price mapping is server-side.
- No secret is exposed to frontend or logs.
- Missing configuration fails safely and diagnostically.

---

# 8. Phase 4 — Backend Checkout and billing API

## Objective

Allow authorised customers to start a paid subscription.

## Suggested API contracts

Adapt to existing route conventions.

Public:
- `GET /api/v1/subscriptions`

Authenticated:
- `GET /api/v1/billing/status`
- `POST /api/v1/billing/checkout`
- `POST /api/v1/billing/portal`
- `POST /api/v1/billing/change_subscription`
- `GET /api/v1/billing/history`

Webhook:
- `POST /api/v1/webhooks/stripe`

Admin:
- plan CRUD;
- feature CRUD;
- plan-feature associations;
- manual assignment;
- subscription/history inspection;
- webhook event inspection/retry where safe.

## Checkout flow

1. Authenticate caller.
2. Resolve the personal or organisation owner from trusted server context.
3. Verify billing-management permission.
4. Validate requested plan slug.
5. Validate plan is active, purchasable and compatible with owner type.
6. Resolve Stripe Price ID on the server.
7. Create/reuse Stripe Customer for that owner.
8. Create Checkout Session with subscription mode.
9. Add safe internal correlation metadata.
10. Use trusted configured success/cancel URLs.
11. Persist local checkout correlation data.
12. Return Checkout URL.

Prevent multiple concurrent active subscriptions for one owner unless explicitly supported.

Use idempotency protection for repeated requests.

## Customer mapping

A Stripe Customer belongs to the billable owner, not automatically to whichever user happens to click Checkout. Multiple organisation administrators must resolve to the same organisation Customer.

## Success/cancel handling

A successful browser redirect only means the customer returned from Checkout. It does not prove that payment succeeded.

The frontend should display a processing state and refresh API billing status. The webhook activates the subscription.

### AI prompt — Phase 4: Checkout and API

```text
Implement the BeachVolleyballHub Rails billing API.

Before coding, inspect the existing authentication, API versioning, serializer and authorization conventions.

Endpoints:
- public subscription catalogue;
- authenticated billing status;
- authenticated Checkout Session creation;
- authenticated Customer Portal session creation;
- subscription history;
- plan-change request endpoint if the agreed change design requires it;
- admin plan/feature management;
- dedicated Stripe webhook endpoint (signature processing is implemented in the webhook phase).

Checkout requirements:
1. Resolve the billing owner from authenticated server-side context.
2. For personal billing, verify the caller owns the personal account.
3. For Club billing, verify the caller has explicit billing-management permission for that organisation.
4. Accept an internal plan slug, not a Stripe Price ID or amount.
5. Verify owner type is compatible with the plan.
6. Resolve the configured Stripe Price ID server-side.
7. Create/reuse one Stripe Customer for the billable owner.
8. Create Checkout Session using subscription mode.
9. Add correlation metadata for owner and plan, but independently verify relationships when processing the webhook.
10. Use trusted success/cancel URLs.
11. Add idempotency and duplicate-subscription protection.
12. Persist enough local correlation data to reconcile Checkout.
13. Return only the fields the frontend needs.

Security:
- prevent IDOR by changing owner IDs;
- prevent a member from managing Club billing without permission;
- rate-limit checkout and portal creation;
- never trust browser redirects as payment confirmation;
- do not log secrets or payment data.

Add request/service specs for success, validation failures, unauthorised owner, wrong plan type, duplicate checkout and Stripe API errors.
```

### Acceptance criteria

- Checkout can be initiated for Player, Coach and Club by the correct owner.
- A user cannot buy a Club plan for an organisation they do not control.
- Browser data cannot alter the amount or Price ID.
- Duplicate requests do not create duplicate active subscriptions.

---

# 9. Phase 5 — Stripe webhooks and reconciliation

## Objective

Keep the local subscription state consistent with Stripe.

## Required webhook properties

- Signature verification against the raw request body.
- Unique Stripe event ID.
- Idempotent event processing.
- Safe handling of duplicate and out-of-order events.
- Persist event receipt before asynchronous processing where appropriate.
- Verify Stripe Customer, Subscription, Price and billable-owner relationships.
- Transactional local updates.
- Append lifecycle history.
- Retry transient processing errors.
- Never log secret or card data.

## Events to evaluate

At minimum:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.finalization_failed` if applicable to the chosen invoice flow.

Use current Stripe API event schemas. Do not assume all events arrive in order.

## Reconciliation

A scheduled job should:
- compare local subscriptions with Stripe;
- repair missed webhook changes;
- detect orphaned Stripe subscriptions;
- detect local subscriptions with missing Stripe records;
- identify owner/customer/Price mismatches;
- record repairs and alert on unresolved discrepancies.

Never silently grant paid entitlements from an unverified record.

## Grace policy

Approve a policy before launch. Suggested starting point:
- active: paid access;
- cancel at period end: paid access until period end;
- past due: paid access during configured grace period;
- unpaid/incomplete-expired: no paid access;
- canceled: no paid access after effective cancellation.

### AI prompt — Phase 5: Webhooks and reconciliation

```text
Implement Stripe webhook processing and subscription reconciliation for BeachVolleyballHub, using the lessons from Wine Words issues #77 and #93.

Webhook:
1. Add a dedicated POST endpoint.
2. Verify Stripe signatures using the raw request body and endpoint-specific secret.
3. Persist Stripe event IDs with a unique constraint.
4. Make processing idempotent.
5. Handle duplicate and out-of-order event delivery.
6. Correlate Checkout Session, Stripe Customer, Stripe Subscription, Stripe Price, internal plan and billable owner.
7. Reject mismatches and suspicious owner/metadata combinations.
8. Update local subscription state from canonical Stripe data.
9. Append lifecycle history for meaningful changes.
10. Use background processing/retries for transient failures where supported.
11. Return HTTP responses consistent with Stripe retry expectations.
12. Never activate a paid plan from the frontend redirect.

Support the agreed lifecycle events, including Checkout completion, subscription create/update/delete, invoice paid and invoice payment failure.

Reconciliation:
- create a scheduled job to compare local and Stripe state;
- repair missed webhook changes safely;
- report orphaned/mismatched records;
- record each repair;
- make repeated runs safe.

Tests:
- valid/invalid signatures;
- duplicate event;
- out-of-order events;
- successful first payment;
- failed first payment;
- successful renewal;
- failed renewal;
- cancellation;
- plan/Price mismatch;
- owner/Customer mismatch;
- transient processing failure and retry;
- reconciliation repair.

Use Stripe test fixtures or official test helpers. Do not use live credentials.
```

### Acceptance criteria

- Webhooks are signed and idempotent.
- Duplicate events do not duplicate history or state changes.
- Out-of-order events do not revert a newer canonical state.
- Reconciliation can repair missed events.
- Payment state cannot be forged through the frontend.

---

# 10. Phase 6 — Upgrade, downgrade, cancellation and renewal

## Objective

Support the complete paid subscription lifecycle.

## Recommended initial business rules

| Change | Behaviour |
|---|---|
| FREE → paid | Stripe Checkout |
| Player → Coach | Immediate upgrade with Stripe proration |
| Coach → Player | Downgrade at renewal |
| Paid → FREE | Cancel at period end |
| Club plan change | Organisation billing administrator only |
| Personal plan change | Personal billing owner only |

These rules require product approval.

## Upgrade

- Use Stripe subscription update.
- Let Stripe calculate proration.
- Define whether the prorated invoice is collected immediately.
- Do not grant the new plan until Stripe confirms the updated subscription/payment state according to the agreed policy.
- Preserve old entitlement if the upgrade payment fails.

## Downgrade

- Schedule the lower plan for the next renewal.
- Keep current paid entitlements until the effective change.
- Persist pending plan change.
- Apply the new plan only when Stripe confirms the change.

## Cancellation

- Default to cancellation at period end.
- Show paid-through date.
- Keep paid access until the end of the period.
- Support cancellation reversal if the Stripe subscription is still active and policy permits it.

## Renewal and payment failure

- `invoice.paid` should update renewal and paid-through dates.
- `invoice.payment_failed` should trigger the documented grace policy and customer notification.
- Avoid duplicate notifications on repeated events.
- Provide a route to update payment method through Customer Portal.

### AI prompt — Phase 6: Lifecycle changes

```text
Implement subscription upgrades, downgrades, cancellation and renewal for BeachVolleyballHub.

Follow the approved business rules and inspect Wine Words issues #73, #80 and #93.

Requirements:
1. FREE to paid uses Checkout.
2. Upgrades use Stripe Billing subscription updates and Stripe-calculated proration.
3. Downgrades are scheduled for renewal unless product decisions say otherwise.
4. Cancellation defaults to period end.
5. Club changes require organisation billing-management permission.
6. Personal changes require personal billing ownership.
7. Persist pending changes and effective dates.
8. Never update local entitlement optimistically before Stripe confirms the operation.
9. Preserve the old valid entitlement if an upgrade payment fails.
10. Correctly process renewals and failed invoices.
11. Avoid duplicate lifecycle history and notifications.
12. Support cancellation reversal where permitted.
13. Protect against concurrent requests and stale state.

Add tests for every transition, payment failures, retries, concurrent change requests, period-end behaviour and organisation authorization.

Document how local state is reconciled if the Stripe API call succeeds but the application request times out.
```

### Acceptance criteria

- Upgrade proration is correct.
- Downgrades do not remove access prematurely.
- Cancellation follows the agreed period-end policy.
- Renewal and failed payment states remain consistent with Stripe.
- Concurrent requests cannot corrupt subscription state.

---

# 11. Phase 7 — Frontend pricing, billing and organisation screens

## Objective

Deliver a responsive customer-facing subscription experience.

## Public pricing page

Display:
- FREE, Player, Coach and Club;
- annual AUD prices;
- features from API;
- limits with understandable wording;
- current plan for authenticated users;
- suitable CTA based on current plan and billing context.

Do not hardcode price or feature catalogue in React.

## Personal billing settings

Display:
- current plan;
- current subscription status;
- included features;
- usage/limits where applicable;
- next renewal or paid-through date;
- pending plan change;
- cancellation state;
- change plan;
- Customer Portal;
- billing history/invoices where supported.

## Organisation billing settings

Display:
- organisation's Club plan;
- billing administrator information;
- organisation feature entitlements;
- seat usage if a seat limit is introduced;
- renewal/cancellation information;
- manage billing action for authorised users only.

Do not show personal payment methods or invoices to organisation members.

## Checkout return

After returning from Stripe:
- show processing state;
- query backend billing status;
- refresh current-user and organisation context;
- retry status retrieval briefly if webhook processing is pending;
- show success only after backend confirms active entitlement;
- show cancellation or failure clearly.

## Admin interface

Provide:
- plan CRUD;
- feature CRUD;
- plan-feature assignment and ordering;
- active/visible/default settings;
- price/limit editing;
- owner subscription inspection;
- history inspection;
- audited manual assignment;
- webhook event/error inspection.

### AI prompt — Phase 7: React UI

```text
Implement the BeachVolleyballHub frontend subscription experience.

Inspect the current Wine Words frontend subscription/pricing UI and adapt its patterns to the BeachVolleyballHub design system, routing, authentication and API client.

Build:
1. Responsive public pricing page for FREE, Player, Coach and Club.
2. Dynamic plan and feature loading from Rails.
3. Current-plan and subscription-status indicators.
4. Personal account billing settings.
5. Organisation billing settings for Club.
6. Billing management controls restricted to authorised owners/admins.
7. Stripe Checkout redirect and return handling.
8. A processing/pending state while waiting for webhook confirmation.
9. Customer Portal redirect.
10. Subscription history and invoice links if provided by the API.
11. Admin plan and feature management.
12. Accessible loading, empty, error and confirmation states.

Rules:
- Never hardcode plan prices or features.
- Never infer payment success from URL parameters.
- Refresh authoritative API state after returning from Stripe.
- Keep personal and organisation billing contexts separate.
- Do not expose one user's billing information to other organisation members.
- Frontend route guards are UX only; backend authorization remains mandatory.
- Ensure desktop, mobile browser and installed PWA layouts work.

Add component, API integration and route tests. Run lint and production build.
```

### Acceptance criteria

- Pricing page is API-driven.
- Checkout return waits for backend state.
- Personal and Club billing screens are separate.
- Organisation billing is hidden from unauthorised members.
- Mobile/PWA experience is usable.

---

# 12. Phase 8 — Backend feature enforcement

## Objective

Enforce plan features at the API boundary.

For each approved feature:
1. Identify relevant controllers, services and operations.
2. Identify create/read/update/delete paths.
3. Identify whether access is personal or organisation-scoped.
4. Add entitlement checks to the policy/service layer.
5. Return consistent error responses.
6. Test direct API access without frontend.

Suggested response:
- HTTP `403 Forbidden`
- application code: `subscription_feature_required`
- required feature slug;
- optional suggested plan slug.

Do not leak internal subscription or payment data in error responses.

### AI prompt — Phase 8: API enforcement

```text
Implement server-side entitlement enforcement for BeachVolleyballHub premium features.

First create a feature-to-endpoint matrix from the approved catalogue. Inspect every relevant controller, policy, service and nested organisation route.

Requirements:
1. Enforce entitlements in backend policy/service boundaries.
2. Distinguish personal and organisation context.
3. Keep role authorization separate from subscription entitlement.
4. Do not rely on frontend visibility or route guards.
5. Return a consistent 403 response with stable code subscription_feature_required.
6. Include only safe upgrade metadata.
7. Ensure organisation features use the selected organisation's Club subscription.
8. Ensure personal features use the personal subscription.
9. Avoid N+1 queries and inconsistent checks.
10. Add request specs for every protected operation.

Test:
- FREE user direct API attempt;
- Player plan;
- Coach plan;
- Club plan;
- user in multiple organisations;
- organisation member without feature entitlement;
- user with a paid personal plan but no Club plan;
- user with Club plan but no personal paid plan;
- Admin/Curator privileges remain intact.

Do not implement new product features; only enforce the approved feature catalogue.
```

### Acceptance criteria

- Premium endpoints reject ineligible requests.
- Entitlements use correct owner context.
- Role permissions remain unchanged.
- Direct API calls cannot bypass subscription rules.

---

# 13. Phase 9 — Quotas, user limits and history rules

## Objective

Build a reusable quota framework while avoiding premature product restrictions.

Potential future limits:
- organisation seats;
- active coaches;
- managed player profiles;
- training sessions;
- assessments;
- video storage;
- historical retention.

Do not invent quota values.

## Requirements

- explicit zero/null semantics;
- unit definition;
- owner scope;
- concurrency-safe usage checks;
- documented counting rules;
- clear frontend usage summaries;
- safe downgrade behaviour;
- no automatic destructive deletion;
- appropriate export/read-only options.

### AI prompt — Phase 9: Quota framework

```text
Implement a generic quota and usage framework for BeachVolleyballHub subscriptions.

Use the approved definitions for Users and History. Do not infer that zero means unlimited.

Requirements:
1. Support explicit zero, positive integer and unlimited/null semantics.
2. Define quota units and owner scope.
3. Make personal and organisation usage independent.
4. Implement usage calculation services.
5. Make enforcement safe under concurrent create requests.
6. Provide consistent API responses when limits are reached.
7. Provide usage summaries for the frontend.
8. Do not delete existing records after downgrade.
9. Support read-only, archive or export behaviour where product policy requires it.
10. Keep unapproved future quotas inactive.

Add tests for zero, finite and unlimited values, concurrency, downgrade, upgrade, archived records and multi-organisation membership.
```

### Acceptance criteria

- Quota meaning is unambiguous.
- Counts are scoped to the correct owner.
- Concurrent operations cannot exceed limits through race conditions.
- Downgrade never silently destroys customer data.

---

# 14. Phase 10 — Security, Cloudflare and operational reliability

## Security checklist

- Stripe secret key server-side only.
- Webhook secret server-side only.
- Verify signatures against raw request body.
- Authorize every billing action.
- Verify organisation billing permissions.
- Prevent owner-ID tampering/IDOR.
- Do not trust browser-supplied Price ID, amount or currency.
- Validate redirect URLs.
- Use idempotency keys.
- Prevent duplicate subscriptions.
- Rate-limit Checkout and Portal session creation.
- Avoid logging payment details/secrets.
- Audit manual admin changes.
- Restrict admin billing operations by least privilege.

## Cloudflare

- Apply suitable WAF/rate-limit controls to billing endpoints.
- Do not cache billing/status/history responses.
- Do not challenge Stripe's server-to-server webhook with Turnstile or interactive bot checks.
- Allow the webhook endpoint to receive Stripe requests.
- If Turnstile is used during checkout initiation, verify its token server-side; it is not a replacement for authentication or authorization.
- Verify Cloudflare rules do not rewrite or block webhook methods/body.

## Reliability and monitoring

Track:
- Checkout Session creation;
- Customer creation/reuse;
- webhook receipt;
- signature failures;
- duplicate events;
- activation and cancellation;
- invoice paid/payment failed;
- plan-change requests/results;
- reconciliation mismatch/repair;
- manual admin assignments.

Alert on:
- repeated webhook failures;
- unresolved Stripe/local mismatches;
- subscriptions without a valid owner;
- customers associated with unexpected owners;
- repeated payment failures where action is needed.

### AI prompt — Phase 10: Security review

```text
Perform a security and reliability implementation review of BeachVolleyballHub Stripe billing.

Inspect all billing routes, policies, services, webhook processing, frontend billing calls and Cloudflare-related deployment configuration.

Verify:
1. Secret keys and webhook secrets are server-side only.
2. Webhook signatures are verified against raw request bodies.
3. Billing owner authorization is enforced.
4. Organisation billing permissions prevent IDOR.
5. Client-supplied amounts/Price IDs are ignored or rejected.
6. Checkout/Portal endpoints are rate-limited.
7. Idempotency and duplicate-subscription protections work.
8. Redirect URLs are trusted and validated.
9. Billing responses are not cached by application or Cloudflare.
10. Stripe webhooks are not blocked by Turnstile or interactive bot challenges.
11. Logs contain useful correlation IDs but no secrets/payment credentials.
12. Manual plan changes are audited.
13. Reconciliation failures are observable and actionable.

Add or update security tests for forged owner IDs, unauthorised organisation billing, replayed webhook events, invalid signatures, malicious redirect values and untrusted Price IDs.

Produce a risk register with severity, evidence and remediation. Fix critical/high issues in scope and report any remaining blockers.
```

### Acceptance criteria

- Security review completed.
- Critical/high billing vulnerabilities fixed.
- Stripe webhooks can reach the API.
- Operational failures are visible.

---

# 15. Phase 11 — Testing and end-to-end acceptance

## API tests

- model constraints;
- seeds;
- entitlement resolver;
- quota semantics;
- checkout;
- customer reuse;
- webhook signature;
- idempotency;
- duplicate/out-of-order events;
- payment success/failure;
- renewal;
- cancellation;
- upgrade/downgrade;
- reconciliation;
- personal/organisation access;
- admin permissions.

## Frontend tests

- pricing catalogue;
- current plan;
- Checkout redirect;
- pending webhook state;
- success/failure/cancel return;
- Customer Portal;
- plan changes;
- personal/organisation separation;
- admin screens;
- mobile/PWA layout.

## Stripe test mode

Use Stripe test mode and Stripe CLI. Test:
- successful payment;
- declined payment;
- authentication-required payment;
- renewal success;
- renewal failure;
- cancellation;
- subscription update/proration.

Do not use live cards for automated tests.

## End-to-end scenario

1. Register a new user.
2. Confirm default FREE.
3. Open pricing page.
4. Choose Player.
5. Start Checkout.
6. Complete test payment.
7. Verify webhook.
8. Verify local subscription active.
9. Verify API entitlements.
10. Verify React refresh.
11. Upgrade to Coach.
12. Verify proration and state.
13. Schedule downgrade.
14. Verify access until period end.
15. Cancel.
16. Verify FREE after paid period ends.
17. Create/use an organisation.
18. Start Club Checkout as authorised billing administrator.
19. Verify Club features in that organisation.
20. Verify an ordinary member cannot manage billing.
21. Verify personal and organisation subscriptions remain independent.

### AI prompt — Phase 11: Full test and acceptance audit

```text
Perform the complete BeachVolleyballHub subscription test and acceptance phase.

Do not assume earlier phases passed; verify the actual implementation.

1. Run Rails model, service, request and policy specs.
2. Run frontend unit/component/integration tests.
3. Run Rails lint and frontend lint.
4. Run production frontend build.
5. Run database migration and seed verification.
6. Run Stripe test-mode Checkout and webhook scenarios.
7. Verify duplicate and out-of-order webhook handling.
8. Verify renewals, failed payments, grace periods and cancellation.
9. Verify upgrade proration and deferred downgrade.
10. Verify personal and organisation billing isolation.
11. Verify direct API feature enforcement.
12. Verify mobile and PWA billing screens.
13. Verify Customer Portal access and owner permissions.
14. Verify reconciliation job behaviour.

For each failure:
- identify exact file and test;
- explain root cause;
- implement an in-scope fix;
- rerun the relevant test.

Output a final acceptance matrix with PASS/FAIL/BLOCKED, evidence and remaining risks. Do not claim completion if a critical lifecycle or authorization test is missing.
```

### Acceptance criteria

- All critical billing lifecycle tests pass.
- No unauthorised owner can manage billing.
- No paid entitlement can be forged.
- Both personal and Club scenarios pass.

---

# 16. Phase 12 — Documentation, deployment and production launch

## Documentation location

Recommended API documentation directory:

`docs/subscriptions/`

Files:
- `README.md`
- `architecture.md`
- `plans-and-features.md`
- `billing-ownership.md`
- `stripe-configuration.md`
- `checkout.md`
- `webhooks.md`
- `subscription-lifecycle.md`
- `entitlements-and-limits.md`
- `admin-guide.md`
- `testing.md`
- `production-deployment.md`
- `troubleshooting.md`
- `security.md`

## Render configuration

Document required environment variables and configure them through Render's secure environment settings.

Use distinct test and production secrets. Do not commit `.env` files or actual secret values.

## Stripe production setup

- Create live Products and Prices.
- Configure the production webhook URL.
- Subscribe to the required events.
- Configure Customer Portal.
- Set allowed return URLs.
- Verify webhook delivery.
- Verify production Price IDs and currency/interval.
- Confirm receipts, support details and customer-facing business information.

## Cloudflare production checks

- Webhook endpoint is reachable.
- No interactive challenge blocks Stripe.
- Billing responses are not cached.
- Rate-limit rules do not prevent legitimate customer actions.
- HTTPS and custom domains are configured correctly.

## Rollback

Document:
- disabling new Checkout initiation;
- preserving existing paid entitlements;
- restoring previous application version;
- reconciling webhook events after recovery;
- manually investigating mismatches;
- avoiding deletion or destructive changes to subscription data.

### AI prompt — Phase 12: Documentation and production readiness

```text
Prepare the complete BeachVolleyballHub subscription documentation and production launch procedure.

Create docs/subscriptions/ with:
- architecture;
- plan and feature catalogue;
- billing ownership;
- Stripe test/live configuration;
- Checkout;
- webhook processing;
- subscription lifecycle;
- entitlement and quota rules;
- admin guide;
- testing;
- production deployment;
- security;
- troubleshooting;
- rollback.

Document:
1. Required Render environment variables by name, never by secret value.
2. Stripe Products and annual Price configuration.
3. Webhook endpoint and subscribed events.
4. Stripe CLI local development.
5. Customer Portal configuration.
6. Cloudflare WAF/rate-limit/cache considerations.
7. Plan and feature administration.
8. Personal versus organisation billing permissions.
9. Payment failure and grace policy.
10. Cancellation, upgrade and downgrade rules.
11. Reconciliation and operational alerts.
12. Refund/dispute support procedure.
13. Deployment, rollback and post-deployment verification.

Review documentation against actual code and configuration. Do not document features that are not implemented. Produce a production readiness checklist and identify any remaining launch blockers.
```

### Acceptance criteria

- Documentation matches actual implementation.
- Render and Stripe configuration steps are reproducible.
- Production webhook and Cloudflare setup are verified.
- Rollback and reconciliation procedures exist.

---

# 17. Recommended delivery sequence

| Sequence | Phase | Primary output |
|---:|---|---|
| 1 | 0 | Audit and decisions |
| 2 | 1 | Database schema and models |
| 3 | 2 | Seed plans and entitlements |
| 4 | 3 | Stripe configuration |
| 5 | 4 | Checkout and billing API |
| 6 | 5 | Webhooks and reconciliation |
| 7 | 6 | Upgrade/downgrade/cancellation |
| 8 | 7 | Frontend billing experience |
| 9 | 8 | Backend feature enforcement |
| 10 | 9 | Quotas and history rules |
| 11 | 10 | Security and reliability |
| 12 | 11 | Testing and acceptance |
| 13 | 12 | Documentation and launch |

Phases 4 and 7 can have parallel frontend/backend work once API contracts are agreed. Do not launch paid access until webhook processing, backend enforcement, security and reconciliation are complete.

---

# 18. Product decisions to confirm

These are the main decisions that should be answered before the relevant code is written.

| Decision | Recommended starting point |
|---|---|
| Currency | AUD |
| Billing frequency | Annual |
| FREE assignment | Automatically assigned to every eligible personal account |
| Users = 0 | Explicitly define; do not assume unlimited |
| History = 0 | Explicitly define; do not assume unlimited |
| Player/Coach ownership | Personal account |
| Club ownership | Organisation |
| Multiple personal plans | One active personal plan at a time |
| Multiple Club plans | One active Club subscription per organisation |
| Upgrade | Immediate with Stripe proration |
| Downgrade | At next renewal |
| Cancellation | At period end |
| Failed renewal | Configurable grace period |
| Data on downgrade | Retain; restrict premium actions rather than delete |

The feature catalogue also needs approval: Player has one feature, Coach has three, and Club has five. Confirm whether higher plans inherit all lower-plan features. The proposal in this document assumes that they do.

---

# 19. Final definition of done

The project is ready for production when:

- [ ] FREE is assigned automatically.
- [ ] Player, Coach and Club plans are configurable.
- [ ] Annual AUD prices are correct.
- [ ] Feature catalogue is editable.
- [ ] Personal and organisation billing owners are isolated.
- [ ] Stripe Checkout works.
- [ ] Signed webhooks update local subscription state.
- [ ] Webhook processing is idempotent.
- [ ] Reconciliation repairs missed events.
- [ ] Renewal and failed-payment behaviour is correct.
- [ ] Upgrade proration works.
- [ ] Downgrade and cancellation timing is correct.
- [ ] Customer Portal works for the correct owner.
- [ ] Backend entitlement enforcement is complete.
- [ ] Role permissions are unaffected by plan changes.
- [ ] Quota semantics are explicit.
- [ ] Downgrade does not delete customer data.
- [ ] Admin catalogue and history screens work.
- [ ] Security and IDOR tests pass.
- [ ] Cloudflare does not block Stripe webhooks.
- [ ] Mobile/PWA billing UI works.
- [ ] Documentation and rollback procedure are complete.
- [ ] Production Stripe and Render configuration are verified.

---

# 20. Reference links

- BeachVolleyballHub API: https://github.com/romalopes/beachvolleyballhub_api
- BeachVolleyballHub frontend: https://github.com/romalopes/beachvolleyballhub_frontend
- Wine Words API: https://github.com/romalopes/wine_words_api
- Wine Words frontend: https://github.com/romalopes/wine_words_front_end
- Wine Words subscription architecture: https://github.com/romalopes/wine_words_api/issues/22
- Wine Words Stripe payment flow: https://github.com/romalopes/wine_words_api/issues/77
- Wine Words subscription changes: https://github.com/romalopes/wine_words_api/issues/73
- Wine Words proration: https://github.com/romalopes/wine_words_api/issues/80
- Wine Words lifecycle/renewal: https://github.com/romalopes/wine_words_api/issues/93
- Stripe subscription use cases: https://github.com/stripe-samples/subscription-use-cases
- Stripe Checkout single subscription: https://github.com/stripe-samples/checkout-single-subscription
- Stripe Billing documentation: https://docs.stripe.com/billing
- Stripe webhooks: https://docs.stripe.com/webhooks
- Stripe Customer Portal: https://docs.stripe.com/customer-management

---

# 21. Implementation record — 14 November 2026

**Status:** all phases implemented. Changes are in the working trees of both
repositories and have not been committed.

Phase records (what was built, files, decisions, tests):
[0](phase-00-audit.md) · [1](phase-01-data-model.md) · [2](phase-02-seeds-entitlements.md) ·
[3](phase-03-stripe-configuration.md) · [4](phase-04-checkout-billing-api.md) ·
[5](phase-05-webhooks-reconciliation.md) · [6](phase-06-lifecycle-changes.md) ·
[7](phase-07-frontend.md) · [8](phase-08-backend-enforcement.md) ·
[9](phase-09-quotas.md) · [10](phase-10-security-reliability.md) ·
[11](phase-11-testing.md) · [12](phase-12-documentation-launch.md)

Operations documentation: [`../subscriptions/`](../subscriptions/README.md).

## 21.1 How the phase prompts were adapted

| Phase | Adaptation |
|---|---|
| 0 | Audited real classes (`User`, `Account`, `Organisation`, `OrganisationMembership`, `OrganisationAccess`); confirmed no billing code existed and Minitest 6 has no mock library |
| 1 | Seven tables; polymorphic owner with DB check constraints; one default plan enforced by a partial unique index; history append-only |
| 2 | FREE is a resolver fallback, so new accounts need no assignment job; no caching |
| 3 | Price mapping via `STRIPE_<SLUG>_YEARLY_PRICE_ID`, validated against Stripe (AUD/yearly) at Checkout time |
| 4 | Only a plan slug is accepted; reusable open Checkout (<30 min); one subscription per owner; admin deactivates referenced plans instead of deleting |
| 5 | Processor stores the last applied event time to ignore stale events; reconciliation reuses the same processor and never revokes access automatically |
| 6 | Downgrades use Stripe Subscription Schedules; local plan changes only on webhook confirmation |
| 7 | `BillingPanel` is shared by personal and club billing; return page polls status; admin catalogue in `/settings/subscriptions` |
| 8 | Enforcement is opt-in (`BILLING_ENFORCEMENT_ENABLED`) and bypassed for admin/curator; explicit personal/organisation context |
| 9 | `nil`/`0`/`n` implemented and tested; no unapproved quota enforced |
| 10 | Rack::Attack webhook safelist and 10/min billing-session throttle; structured `billing.*` logs; sanitised event payloads |
| 11 | 82 billing tests; full suite 1834 runs with two pre-existing unrelated failures; 19 pre-existing frontend failures reproduce at HEAD |
| 12 | 13 operational docs and 13 phase records; launch checklist and rollback procedure |

## 21.2 What must be configured

**API environment:** `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`STRIPE_PLAYER_YEARLY_PRICE_ID`, `STRIPE_COACH_YEARLY_PRICE_ID`,
`STRIPE_CLUB_YEARLY_PRICE_ID`, `APP_FRONTEND_URL`. Optional:
`STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`, `STRIPE_PORTAL_RETURN_URL`,
`BILLING_GRACE_PERIOD_DAYS`, `BILLING_ENFORCEMENT_ENABLED`,
`STRIPE_PUBLISHABLE_KEY`.

**Stripe:** three live annual AUD Products/Prices; webhook
`POST https://<api>/api/v1/webhooks/stripe` subscribed to
`checkout.session.completed`, `checkout.session.async_payment_succeeded`,
`checkout.session.async_payment_failed`, `customer.subscription.created`,
`customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`,
`invoice.payment_failed`, `invoice.finalization_failed`; Customer Portal with
payment methods, invoices and cancellation; business/receipt details.

**Render:** the variables above on the web service and the Solid Queue worker (the
daily reconciliation job runs there). Run `db:migrate` then `db:seed` on deploy.

**Cloudflare:** allow the webhook without Turnstile/bot challenge, do not cache
`/api/v1/billing/*` or `/api/v1/webhooks/stripe`, do not rewrite its body.

**Frontend:** no secrets or billing configuration; it uses the existing
`VITE_API_BASE_URL`/proxy. New routes: `/subscribe`, `/billing`, `/billing/return`,
`/organisations/:id/billing`, `/settings/subscriptions`.

## 21.3 Product decisions still required before charging real customers

1. Confirm AUD pricing (Player 5, Coach 10, Club 50 per year) and annual billing.
2. Approve the public feature names and the Player/Coach/Club mapping.
3. Confirm `Users = 0` / `History = 0` mean “owner access only / no extended
   retention” (as implemented).
4. Decide whether `BILLING_ENFORCEMENT_ENABLED` launches on.
5. Agree the grace period (default 7 days), refund and dispute handling.
6. Decide whether clubs may self-cancel from the Portal or must contact support.

## 21.4 Definition-of-done status

| Item | Status |
|---|---|
| FREE assigned automatically | Yes — resolver fallback, no row required |
| Configurable Player/Coach/Club plans | Yes |
| Annual AUD prices | Yes (catalogue + Stripe Price validation) |
| Editable feature catalogue | Yes (admin API + UI) |
| Isolated personal/organisation billing | Yes |
| Stripe Checkout works | Yes (tested with stubs; live keys still to configure) |
| Signed webhooks update state | Yes |
| Idempotent webhook processing | Yes (unique event id + tests) |
| Reconciliation repairs missed events | Yes (daily job) |
| Renewal and failed-payment behaviour | Yes (invoice events + grace) |
| Upgrade proration | Yes (`always_invoice`) |
| Downgrade/cancellation timing | Yes (schedule at renewal; cancel at period end) |
| Customer Portal per owner | Yes |
| Backend entitlement enforcement | Yes, flag-gated |
| Role permissions unaffected | Yes (separate layer, admin bypass) |
| Quota semantics explicit | Yes |
| Downgrade does not delete data | Yes |
| Admin catalogue/history screens | Yes |
| Security/IDOR tests | Yes |
| Cloudflare does not block webhooks | Documented; operator must verify live |
| Mobile/PWA billing UI | Responsive; inherits the existing PWA shell |
| Documentation and rollback | Yes |
| Production Stripe/Render verified | **Pending operator action** (no live credentials in the repo) |

