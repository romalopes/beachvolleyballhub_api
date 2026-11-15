# Billing ownership

## Two owners, never mixed

| Plan | Owner type | Where billing is managed |
|---|---|---|
| Player | `Account` (the signed-in person) | `/billing` |
| Coach | `Account` | `/billing` |
| Club | `Organisation` (the club itself) | `/organisations/:id/billing` |
| FREE | Either (fallback, never purchased) | — |

A user may be a Coach with a personal Coach plan *and* an owner of a club with a
Club plan. Those are two independent records, two Stripe Customers and two sets
of entitlements. A Club plan never makes its members paid Coaches, and a personal
plan never unlocks club-level features.

## Who may act

`Billing::OwnerResolver` is the only place that decides:

- **Personal**: always `Current.user.account`. There is no `owner_id` parameter,
  so one account cannot address another's billing.
- **Organisation**: the caller must be an active `owner` or `administrator` of
  that exact organisation (`OrganisationAccess.manages_membership?`). Site
  admins/curators may also act in support; their actions are auditable.
- Organisation hierarchy is *not* access: being in a parent federation does not
  grant billing rights over a child club.

Roles (player/coach/curator/admin) are unrelated to subscription ownership. An
admin does not need a plan; a Coach on FREE remains a Coach.

## Stripe Customer rules

- Exactly one Stripe Customer per billable owner (`billing_customers` unique on
  both the owner pair and `stripe_customer_id`).
- Two club administrators resolve to the **same** Customer, because the mapping
  is on the organisation, not on the user who clicked Checkout.
- A personal Customer is never reused for a club purchase.

## What a member can see

`GET /api/v1/billing/status` for an organisation is authorized like every other
billing action: a member without billing permission gets `403`, with no billing
payload. There is no "billing exists" boolean leaking through a public endpoint.

## Manual assignment

`POST /api/v1/admin/billing/assignments` lets an admin grant a plan with a
mandatory reason. It:

- writes an append-only history row (`source: admin`) and an audit log entry;
- refuses to overwrite a subscription managed by Stripe (the next webhook would
  revert it, and the two systems would disagree in the meantime).

## Data retention

Billing records are never cascaded from `Account` or `Organisation`
(`dependent: :restrict_with_error`). Deleting an identity that owns billing
history fails loudly rather than silently destroying invoices or lifecycle rows.
