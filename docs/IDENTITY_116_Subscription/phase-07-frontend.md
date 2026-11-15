# Phase 7 — Frontend subscription experience

**Status:** complete

## Objective

An API-driven pricing page, personal and club billing screens, a safe checkout
return, and an admin catalogue — responsive and installable (PWA).

## Implemented (frontend repository)

| File | Purpose |
|---|---|
| `src/api.ts` | Billing types and methods (`subscriptions`, `billingStatus`, `billingHistory`, `createCheckout`, `createBillingPortal`, `changeSubscription`, admin catalogue/assignment/events/diagnostics) |
| `src/pages/Subscribe.tsx` | Public pricing grid from the catalogue; personal checkout; club links; upgrade/downgrade requests |
| `src/pages/Billing.tsx` | `BillingPanel` used for personal and club billing: plan, status, renewal/access-until, grace warning, pending change, features, limits/usage, portal, cancel/resume, history |
| `src/pages/BillingReturn.tsx` | Checkout return; polls status, never grants |
| `src/pages/OrganisationBilling.tsx` | `/organisations/:id/billing` with explicit organisation context |
| `src/pages/settings/Subscriptions.tsx` | Admin plans, features, feature mapping, manual assignment, diagnostics, webhook events |
| `src/components/billing/BillingHistoryList.tsx` | Append-only history table |
| `src/App.tsx`, `src/components/Sidebar.tsx`, `src/App.css` | Routes, navigation, responsive styles |
| `src/pages/Subscribe.test.tsx`, `Billing.test.tsx` | Component/API integration tests |

## Behavioural guarantees

- Prices, features and limits are read from `GET /subscriptions`; nothing is
  hardcoded in React except layout.
- Checkout posts `{ plan_slug }` (plus owner context for clubs). No price or Price
  ID exists in the client.
- `/billing/return` treats `checkout=success` as a hint: it polls
  `GET /billing/status` and shows processing until the webhook-confirmed state
  arrives.
- Personal and club billing are separate routes and owner contexts; a club member
  without rights gets the API's 403.
- Route guards are UX only; the API remains the security boundary.

## Mobile / PWA

The pricing grid is `auto-fit minmax(240px, 1fr)`; the billing summary stacks under
768px; tables scroll horizontally. The app already ships a PWA manifest and
offline shell, so the new routes inherit it.

## Tests and checks

```bash
cd beachvolleyballhub
npx tsc -b
npm run lint
npx vitest run src/pages/Subscribe.test.tsx src/pages/Billing.test.tsx
```

`Subscribe.test.tsx` proves the catalogue rendering and that Checkout receives only
the plan slug. `Billing.test.tsx` proves status rendering and the cancellation
payload.

Known pre-existing failures (identical at HEAD): `App.test.tsx` (`matchMedia` in
jsdom), `Home.test.tsx`, `TrainingFormPage.test.tsx`. They are unrelated to
billing; the billing tests pass.

## Follow-ups (not implemented)

- A visual proration preview before an upgrade (requires Stripe's upcoming-invoice
  API and a product decision).
- Seat purchase UI (no seats are sold yet).
- Invoice list in-app (the Customer Portal covers it).
