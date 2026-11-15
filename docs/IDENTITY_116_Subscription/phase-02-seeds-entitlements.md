# Phase 2 — Seeds and entitlement resolver

**Status:** complete

## Objective

Seed the four plans and the five features idempotently, then make one service the
single answer to “what may this owner use?”.

## Implemented

- `db/seeds/subscriptions.rb` — FREE (0, default, both), Player (500, personal),
  Coach (1000, personal), Club (5000, organisation), five features, ordered
  mappings. Creates only what is missing; never overwrites admin edits or removes a
  mapping. Invoked from `db/seeds.rb`.
- `app/services/entitlements/resolver.rb` — plan, entitlement, features, limits,
  usage, suggested plan, summary. Reads the billing record directly to avoid a
  stale association.
- `app/services/entitlements/quota.rb` — `nil` unlimited, `0` none, `n` explicit.
- `app/services/entitlements/usage.rb` — counts active organisation memberships
  and history rows; not applicable for personal seats.

## Status policy

`active`/`trialing` grant access; `past_due` only within grace;
`incomplete`, `incomplete_expired`, `unpaid`, `canceled`, `paused` do not;
`cancel_at_period_end` keeps access to `current_period_end`; no record or an
inactive plan falls back to FREE.

## Decisions

- FREE is a fallback, not a row that must exist for every account. A new account is
  entitled to FREE the moment it exists; no backfill or hook is needed.
- No caching. A stale grant is a security bug; one indexed query is not.
- Personal and organisation resolution is explicit at every call site, never
  inferred.

## Configuration

None. Seeds are data; the resolver depends only on the catalogue.

## Tests

`test/services/entitlements/resolver_test.rb` — 12 tests: FREE fallback, active
plan features, past_due inside/outside grace, cancel-at-period-end before/after
period end, canceled/unpaid/incomplete, retired plan, personal vs organisation,
multiple organisations, User resolution, nil/zero/positive limits, seat counting,
suggested plan.

## Verification

```bash
bin/rails db:seed
bin/rails runner 'puts Subscription.ordered.pluck(:slug, :yearly_price_cents).inspect'
bin/rails test test/services/entitlements/resolver_test.rb
```
