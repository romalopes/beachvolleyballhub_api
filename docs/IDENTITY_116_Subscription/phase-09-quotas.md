# Phase 9 — Quotas and history rules

**Status:** complete (framework; no unapproved quota values)

## Objective

Provide a transaction-safe quota model with explicit zero/null semantics, without
inventing product limits.

## Implemented

- `app/services/entitlements/quota.rb` — `unlimited?`, `exceeded?`, `remaining`,
  `describe`. `nil` never exceeds; `0` exceeds at any usage; `n` is a maximum.
- `app/services/entitlements/usage.rb` — `value_for(owner, limit)`, `included_users`,
  `history_rows`, `summary` (limit, usage, remaining, unlimited, exceeded).
- `Entitlements::Resolver#limit_for`, `#usage_for`, `#exceeded?`.
- API payloads expose `limits` (value + human label) and `usage` per limit, which
  the billing page renders (“Owner access only · 0 in use”, “No extended history”).

## Semantics

| Limit | Owner scope | Counts | Not applicable |
|---|---|---|---|
| `included_users` | Organisation | active `OrganisationMembership` rows | personal Account → `nil` |
| `history_limit` | Either | `subscription_histories` rows | — |

The launched catalogue sets both to `0`: the owner has access, no extra seats and
no extended retention. `0` is not unlimited.

## Concurrency and downgrade

- `Quota.exceeded?` is a pure function; the caller performs the check inside the
  operation's transaction/lock when a finite quota is actually enforced.
- No downgrade path deletes or archives customer data. Exceeding a limit restricts
  the next operation; it never truncates existing rows.
- A future finite limit must define its counting scope (deleted/archived included
  or not) and get a migration + request spec before enforcement.

## Tests

`test/services/entitlements/resolver_test.rb`:

- `nil` unlimited never exceeds; `0` exceeds at zero usage; `n` boundaries;
- remaining clamps at zero; unlimited remaining is `nil`;
- organisation seat usage equals active memberships; personal seat usage is `nil`.

## Follow-ups

- Approve at least one finite quota with a product decision before enforcing any.
- If usage checks become write paths, wrap count + create in a lock to avoid a race.
- Expose an export/read-only policy if a future retention limit would hide data.
