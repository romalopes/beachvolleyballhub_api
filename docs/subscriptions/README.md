# Subscriptions and Stripe billing

BeachVolleyballHub sells annual Player, Coach and Club plans through Stripe
Billing. This directory is the operational and engineering documentation for that
integration. It describes what is implemented, not an aspiration.

## Read in this order

| Document | Purpose |
|---|---|
| [architecture.md](architecture.md) | Components, ownership model and data flow |
| [plans-and-features.md](plans-and-features.md) | The catalogue, prices and limit semantics |
| [billing-ownership.md](billing-ownership.md) | Personal vs organisation billing, permissions |
| [stripe-configuration.md](stripe-configuration.md) | Test/live setup, environment variables, Price mapping |
| [checkout.md](checkout.md) | Checkout Session creation and the return flow |
| [webhooks.md](webhooks.md) | Signature verification, events, idempotency, reconciliation |
| [subscription-lifecycle.md](subscription-lifecycle.md) | Upgrade, downgrade, renewal, grace, cancellation |
| [entitlements-and-limits.md](entitlements-and-limits.md) | How access and quotas are resolved and enforced |
| [admin-guide.md](admin-guide.md) | Catalogue management and manual assignments |
| [security.md](security.md) | Threat model, IDOR, secrets, rate limits, Cloudflare |
| [testing.md](testing.md) | Automated tests and manual Stripe test-mode checks |
| [production-deployment.md](production-deployment.md) | Render/Stripe/Cloudflare launch and rollback |
| [troubleshooting.md](troubleshooting.md) | Symptom → cause → action |

Phase-by-phase implementation notes live in
[`../IDENTITY_116_Subscription/`](../IDENTITY_116_Subscription/).

## The five rules everything else follows

1. **The webhook is the authority.** A browser redirect never activates a plan.
2. **The API enforces.** The SPA hides what is unavailable; it never grants it.
3. **The owner is explicit.** Personal (Account) and organisation (Organisation)
   billing are separate records, separate Stripe Customers, separate permissions.
4. **Roles are not subscriptions.** A Coach on FREE is still a Coach; a paid
   plan never grants admin/curator authority.
5. **Nothing is destroyed.** Plans are deactivated, history is append-only, and a
downgrade restricts future actions instead of deleting content.

## Current status

Implemented in this repository:

- Catalogue, feature catalogue and ordered plan-feature associations.
- Billable owner records, Stripe Customer mapping, checkout correlation,
  append-only history and webhook audit ledger.
- Public catalogue API, owner-scoped billing API, signed webhook endpoint and
  admin catalogue/assignment/diagnostics endpoints.
- Checkout, Customer Portal, upgrade/downgrade/cancellation requests,
  webhook-driven state and daily reconciliation.
- Central entitlement resolver, quota semantics and opt-in API enforcement.
- React pricing, personal billing, club billing, checkout return and admin pages.

Not implemented (by design, pending product decisions): trials, multiple
concurrent personal plans, seat purchase add-ons, proration previews, and any
quota value other than the launched `0 = owner access only`.
