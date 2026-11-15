# Entitlements and limits

## One resolver

`Entitlements::Resolver` is the only place subscription state becomes a permission.
Controllers, policies, the API payload and the SPA all read the same answer.

```ruby
resolver = Entitlements::Resolver.new(owner) # Account, Organisation, User or nil
resolver.plan                             # the effective plan (FREE fallback)
resolver.entitled?                        # paid access right now?
resolver.feature_enabled?("club_reporting")
resolver.effective_features               # ordered SubscriptionFeature rows
resolver.limit_for(:included_users)       # nil | 0 | n
resolver.usage_for(:history_limit)
resolver.exceeded?(:included_users)
resolver.suggested_plan_for("advanced_training_planning")
```

## Status policy

| Stripe status | Paid access |
|---|---|
| `active` | yes (unless `cancel_at_period_end` and the period has ended) |
| `trialing` | yes |
| `past_due` | yes only inside the grace window |
| `incomplete` | no |
| `incomplete_expired` | no |
| `unpaid` | no |
| `canceled` | no |
| `paused` | no |
| no record | FREE |
| plan inactive/retired | FREE (never “everything the old plan had”) |

`cancel_at_period_end` keeps access to `current_period_end`.

## Enforcement at the API boundary

`SubscriptionEntitlement#require_subscription_feature!` is included by controllers
whose operations are sold:

| Feature | Endpoint(s) | Owner context |
|---|---|---|
| `advanced_training_planning` | `POST/PATCH training_templates`, archive/restore/clone; `training_series` preview/create/bulk/stop/split/update_future | personal |
| `advanced_assessments` | `assessment_sessions` create/update/publish/restore | personal |
| `organisation_management` | `PATCH organisations/:id`, archive/restore/logo | organisation |
| `club_reporting` | `GET organisations/:id/coaches` | organisation |

Response when not entitled:

```json
{
  "error": "This feature requires a subscription",
  "code": "subscription_feature_required",
  "feature": "advanced_training_planning",
  "current_plan": "free",
  "suggested_plan": { "slug": "coach", "name": "Coach", "yearly_price_cents": 1000, "currency": "AUD" }
}
```

`403`. No prices paid, invoices or Stripe ids are leaked.

### Enforcement is opt-in

`BILLING_ENFORCEMENT_ENABLED=true` turns the checks on. It is off by default so a
deployment can ship the catalogue and UI before changing existing role-based
behaviour. Site admins and curators bypass subscription checks (oversight is not a
product); role authorization still runs first and is unchanged — a Coach on FREE
is still a Coach, they just cannot use a premium Coach operation.

### Owner context

- Personal features resolve against `Current.user.account`.
- Organisation features resolve against the selected `@organisation`, whose Club
  subscription is independent of any personal plan.
- A personal Coach plan never unlocks club management; a Club plan never unlocks
  personal Coach features.

## Limits and quotas

`Entitlements::Quota`:

- `nil` = unlimited / not applicable — never exceeded;
- `0` = none — exceeded at any usage;
- `n` = explicit maximum.

`Entitlements::Usage.value_for(owner, limit)` counts active organisation members
for `included_users` (nil for a personal account) and history rows for
`history_limit`. `Entitlements::Usage.summary` returns limit, usage, remaining and
an exceeded flag for the UI.

No quota value other than `0` is enforced today, because no other value has been
approved. The framework is in place so approving one is configuration plus a
counting rule, not a redesign.

## Downgrade behaviour

Nothing is deleted on downgrade. The resolver simply stops granting features the
new plan does not include; existing rows (sessions, assessments, history) remain
readable and retained. Premium *actions* are restricted, not customer data.

## Caching

None. Entitlements are read fresh from one indexed row per request. If caching is
added later it must be invalidated by the webhook and reconciliation writes; a
stale grant is a security bug, a duplicate query is not.
