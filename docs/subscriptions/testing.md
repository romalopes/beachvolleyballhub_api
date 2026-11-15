# Testing

## Automated (API)

```bash
cd beachvolleyballhub_api
RAILS_ENV=test bin/rails db:test:prepare
bin/rails test test/models/subscription_test.rb \
  test/services/entitlements test/services/billing \
  test/controllers/api/v1/subscriptions_controller_test.rb \
  test/controllers/api/v1/billing_controller_test.rb \
  test/controllers/api/v1/webhooks_stripe_controller_test.rb \
  test/controllers/api/v1/admin/subscriptions_controller_test.rb \
  test/controllers/api/v1/subscription_enforcement_test.rb
```

Coverage:

| Area | File | What it proves |
|---|---|---|
| Catalogue | `test/models/subscription_test.rb` | one default, free default, cent prices, owner scope, feature counts, delete guard |
| Entitlements | `test/services/entitlements/resolver_test.rb` | FREE fallback, active/past_due/canceled, grace, period end, retired plans, personal vs organisation, quota semantics |
| Webhooks | `test/services/billing/webhook_processor_test.rb` | activation, duplicate, out-of-order, unknown Price, metadata mismatch, invoice events, checkout completion, cancellation |
| Reconciliation | `test/services/billing/reconciliation_service_test.rb` | drift repair, missing-in-Stripe report, orphan recreation |
| Checkout | `test/services/billing/checkout_service_test.rb` | server Price, subscription mode, reuse, duplicate subscription, owner eligibility |
| Plan changes | `test/services/billing/plan_change_service_test.rb` | upgrade proration, deferred downgrade, cancel/resume, no optimistic change |
| HTTP contracts | `test/controllers/api/v1/*billing*`, `*subscriptions*`, `*webhooks*` | auth, owner authorization, status payloads, error codes, signature handling |
| Enforcement | `test/controllers/api/v1/subscription_enforcement_test.rb` | free coach blocked, paid coach allowed, admin bypass, club needs Club plan, flag off = unchanged |

The suite stubs `Billing::StripeGateway` at the seam (Minitest 6 ships no
`minitest/mock`; `test/test_helpers/billing_test_helper.rb` restores the original
method in `ensure`). No network call is made by any billing test.

Run the whole suite with `bin/rails test`. Current baseline: 1834 runs; two
pre-existing environment-dependent failures remain outside this feature
(`HealthControllerTest` mail-transport expectation and a weather-share date
format), plus nothing in the billing files.

## Automated (frontend)

```bash
cd beachvolleyballhub
npx tsc -b
npm run lint
npx vitest run src/pages/Subscribe.test.tsx src/pages/Billing.test.tsx
```

`Subscribe.test.tsx` asserts the catalogue, prices, features and that Checkout
receives only `{ plan_slug }`. `Billing.test.tsx` asserts the plan, renewal date,
limits, portal control, and the cancellation request payload.

The repository has 19 pre-existing failures in `App.test.tsx`, `Home.test.tsx`
and `TrainingFormPage.test.tsx` (jsdom `matchMedia` and test isolation issues) that
are identical at HEAD without this feature; the billing files pass.

## Manual Stripe test-mode checklist

Use test cards from Stripe's documentation.

1. Register/sign in, open `/subscribe`, choose Player → redirected to Checkout.
2. Pay with `4242 4242 4242 4242`. Return page shows “Activating…” then Player.
3. `GET /api/v1/billing/status` shows `plan.slug = player`, `entitled = true`.
4. Upgrade to Coach at `/billing` → Stripe prorated invoice; status remains Player
   until the webhook arrives, then Coach; history shows the change.
5. Schedule a downgrade → status shows the pending change with the renewal date;
   features stay Coach until then.
6. Cancel at period end → status shows access-until; `resume` reverses it.
7. Fail a renewal (`4000 0000 0000 0341` or Stripe's failure test clocks) →
   `past_due`, grace shown, access continues; pay → grace cleared.
8. Duplicate a webhook (`stripe events resend <id>`) → second delivery is a no-op.
9. Open `/billing` and click “Manage payment method & invoices” → Portal opens for
   the correct Customer.
10. As a club owner, subscribe the club from `/organisations/:id/billing`; confirm
    a non-manager member gets 403 and that a personal plan does not unlock club
    management.
11. Admin: `/settings/subscriptions` — edit a price, toggle visibility, reorder
    features, assign a plan with a reason, inspect events/diagnostics.

## Migration checks

```bash
bin/rails db:migrate
bin/rails db:rollback STEP=4
bin/rails db:migrate
```

All four migrations apply and roll back cleanly (verified).
