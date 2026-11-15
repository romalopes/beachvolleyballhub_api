# Phase 0 — Audit and decisions

**Status:** complete · **Code changed:** none

## Objective

Inspect both repositories and the existing identity/organisation model before
designing subscriptions; resolve the product ambiguities the plans flagged.

## Audit findings

- Rails 8.1.3 / Ruby 3.4.2, PostgreSQL, cookie + bearer session authentication,
  Pundit policies, Solid Queue/Cache/Cable.
- Identity is `User` (credentials, roles) → `Account` (contact details, profiles).
  `Organisation` is a hierarchical club/federation with `OrganisationMembership`
  (owner/administrator/coach/member, active/pending/suspended/ended).
- `OrganisationAccess` already centralises membership-to-capability rules; it is
  reused for club billing authorization.
- No existing billing, Stripe, invoice or subscription code; the `stripe` gem was
  not present.
- Background jobs: ActiveJob + Solid Queue; `config/recurring.yml` already used for
  scheduled work.
- API conventions: `/api/v1`, JSON, `{ data: ... }`/`{ errors: [...] }`,
  `X-Idempotency-Key` middleware, Rack::Attack, Sentry, structured logging.
- Frontend: React 19 + Vite + React Router 7, one `src/api.ts` client,
  `useAuth`, API base URL `/api/v1` behind a proxy, Vitest + Testing Library.
- Existing test suites: 1834 API runs and 1212 frontend tests; 19 frontend failures
  already existed at HEAD in `App/Home/TrainingFormPage` (jsdom `matchMedia` and
  isolation), independent of this feature.

## Decisions taken

| Question | Decision |
|---|---|
| Billable owner | Polymorphic, restricted to `Account` (personal) and `Organisation` (club) |
| FREE assignment | Resolver fallback: no paid record means the default FREE plan; no row is required |
| `Users = 0` | No additional seats beyond owner access. `NULL` would mean unlimited |
| `History = 0` | No extended retention. `NULL` would mean unlimited |
| Club seats | None in this release (`included_users = 0`) |
| Feature catalogue | Player 1, Coach 3, Club 5, as proposed |
| Multiple personal plans | One active personal plan; `billing_subscriptions` is unique per owner |
| Multiple club plans | One Club subscription per organisation |
| Club billing rights | Active club owner/administrator; site admin for support; hierarchy is not access |
| Upgrade | Immediate with Stripe proration (`always_invoice`) |
| Downgrade | Scheduled at renewal via Stripe Subscription Schedule |
| Cancellation | At period end, reversible |
| Failed payment grace | `BILLING_GRACE_PERIOD_DAYS`, default 7 |
| Data on downgrade | Retained; premium actions restricted, nothing deleted |
| Enforcement | Implemented but opt-in via `BILLING_ENFORCEMENT_ENABLED` |
| Plan/Price mapping | Server environment, `STRIPE_<SLUG>_YEARLY_PRICE_ID`; DB fallback |

## Deliverables

- This audit record.
- The model/ownership decision (ADR-style notes in
  `docs/subscriptions/billing-ownership.md`).
- Confirmed catalogue and limit semantics
  (`docs/subscriptions/plans-and-features.md`).
- File-by-file implementation map (see Phase 1–12 records).

## Risks recorded

- A second subscription system must not be created: the Account/Organisation
  model is reused, not wrapped.
- Enforcement applied to existing coach operations changes customer behaviour, so
  it is flag-gated per environment.
- Stripe Prices can drift from the catalogue; the chosen rule is “environment
  Price wins, catalogue price is display/comparison”, validated on every Checkout.
