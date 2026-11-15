# Phase 11 — Testing and acceptance

**Status:** complete for automated coverage; manual Stripe test-mode checklist
documented

## Objective

Prove the security, lifecycle, entitlement and organisation-permission behaviour,
and record the acceptance flow for a human tester.

## Test inventory (API)

| File | Tests |
|---|---|
| `test/models/subscription_test.rb` | 8 |
| `test/services/entitlements/resolver_test.rb` | 13 |
| `test/services/billing/webhook_processor_test.rb` | 11 |
| `test/services/billing/checkout_service_test.rb` | 7 |
| `test/services/billing/plan_change_service_test.rb` | 8 |
| `test/services/billing/reconciliation_service_test.rb` | 3 |
| `test/controllers/api/v1/subscriptions_controller_test.rb` | 2 |
| `test/controllers/api/v1/billing_controller_test.rb` | 9 |
| `test/controllers/api/v1/webhooks_stripe_controller_test.rb` | 5 |
| `test/controllers/api/v1/admin/subscriptions_controller_test.rb` | 10 |
| `test/controllers/api/v1/subscription_enforcement_test.rb` | 6 |

Fixtures: `subscriptions.yml`, `subscription_features.yml`,
`subscription_subscription_features.yml` (FREE default, Player 1, Coach 3, Club 5,
plus a retired plan/feature). A `BillingTestHelper` creates owner records and builds
Stripe-shaped event hashes; the Stripe gateway is stubbed at one seam (Minitest 6
ships no mock library).

## Results

- Billing/entitlement/controller tests: **all passing**.
- Full API suite: 1834 runs, 0 errors, 2 failures — both pre-existing and unrelated:
  `HealthControllerTest` expects the `auto` mail transport while this shell has
  `BREVO_API_KEY`, and a weather-share assertion depends on the fixture date.
- Frontend: `Subscribe`/`Billing` tests pass; `tsc` and ESLint clean for the new
  files. The 19 pre-existing failures in `App/Home/TrainingFormPage` reproduce at
  HEAD without this change.
- Migrations apply and roll back; `zeitwerk:check` passes; RuboCop clean on the new
  code.

## Manual acceptance flow

1. Register, open `/subscribe`: FREE is assigned (fallback), Player/Coach/Club list.
2. Choose Player → Stripe test Checkout → pay `4242 4242 4242 4242`.
3. Return page shows processing then Player; `/billing` shows the renewal date.
4. Upgrade to Coach → prorated invoice; status flips only after the webhook.
5. Schedule a downgrade → paid access remains until renewal.
6. Cancel at period end → access-until shown; resume works.
7. Fail a renewal → grace warning; pay → cleared.
8. Repeat with a club owner on `/organisations/:id/billing`; a member without rights
   gets 403; a personal plan does not unlock club management.
9. Admin: edit catalogue, map features, assign a plan with a reason, inspect events.

## Not automated here

Live Stripe interactions (they need real test-mode keys and a forwarded webhook) and
browser/PWA visual checks. The commands and expected outcomes are in
`docs/subscriptions/testing.md`.
