# Plans and features

## Catalogue

Seeded by `db/seeds/subscriptions.rb` (idempotent, run from `db/seeds.rb`).

| Slug | Name | Annual price | Owner scope | Default | Features |
|---|---|---:|---|---|---:|
| `free` | FREE | A$0 | both | yes | 0 |
| `player` | Player | A$5 | personal | no | 1 |
| `coach` | Coach | A$10 | personal | no | 3 |
| `club` | Club | A$50 | organisation | no | 5 |

Money is stored as integer cents (`yearly_price_cents`) plus an ISO-4217 currency
(`AUD`). The database rejects negative prices, malformed currencies and unknown
owner scopes, and enforces exactly one default plan via a partial unique index.

A reseed never overwrites an existing plan's price, name or flags, and never
removes an administrator's feature mapping. It only creates what is missing.

## Features

Features are a standalone catalogue. `slug` is the stable identity the API
enforces; `name` is display only and can be renamed without code changes.

| Slug | Name | Player | Coach | Club |
|---|---|:---:|:---:|:---:|
| `enhanced_player_profile` | Enhanced personal player profile | yes | yes | yes |
| `advanced_training_planning` | Advanced training planning | | yes | yes |
| `advanced_assessments` | Advanced assessments and player development | | yes | yes |
| `organisation_management` | Organisation management | | | yes |
| `club_reporting` | Club-level reporting and management | | | yes |

Higher plans list the lower plan's features explicitly; nothing is inherited
implicitly, so the pricing page and the resolver cannot disagree.

## Limit semantics

Limits are nullable integers with an explicit meaning:

| Value | Meaning |
|---|---|
| `NULL` | Unlimited / not applicable |
| `0` | None beyond the documented owner access |
| `n > 0` | An explicit quota |

The launched catalogue sets both `included_users` and `history_limit` to `0`:
the owner has access, but no additional seats and no extended retention. `0` is
never treated as unlimited. `Entitlements::Quota` implements the rules and
`Entitlements::Usage` counts the current usage:

- `included_users`: active organisation memberships. Not applicable to a personal
  Account (returns `nil`), because the owner is not a seat.
- `history_limit`: lifecycle history rows retained for the owner.

## Changing the catalogue

Admins can edit the catalogue price, flags, order and feature mappings at
`/settings/subscriptions` or via `/api/v1/admin/subscriptions`.

**Changing a plan's price does not change what existing subscribers pay.** Their
Stripe Subscription keeps its Price. Moving them requires an explicit Stripe
Price migration and a recorded plan change; the local catalogue is not an
instruction to Stripe.

To sell a new plan: create the Stripe Product/Price, set
`STRIPE_<SLUG>_YEARLY_PRICE_ID`, then add the plan and its features here.

## API shapes

`GET /api/v1/subscriptions` returns:

```json
{
  "data": [
    {
      "id": 2, "name": "Player", "slug": "player",
      "yearly_price_cents": 500, "yearly_price": "5.00",
      "price_label": "A$5.00/year", "currency": "AUD",
      "owner_scope": "personal", "default": false, "popular": true,
      "purchasable": true, "stripe_price_configured": true,
      "included_users": 0, "history_limit": 0,
      "features": [{ "slug": "enhanced_player_profile", "name": "..." }]
    }
  ],
  "meta": { "currency": "AUD", "billing_configured": true, "enforcement_enabled": true }
}
```

`stripe_price_configured` reports whether the server has a Price for the plan; the
Price ID itself is never returned to the browser.
