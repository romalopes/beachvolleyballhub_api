# Phase 8 — Backend feature enforcement

**Status:** complete (opt-in)

## Objective

Enforce the approved features at the API boundary, independently of the SPA, and
without turning subscriptions into a second roles system.

## Implemented

- `app/controllers/concerns/subscription_entitlement.rb` — `require_subscription_feature!`
  with an explicit owner context, admin/curator bypass, env flag, and a stable 403
  response carrying only safe upgrade metadata.
- Included and wired in:
  - `training_templates_controller.rb` — create/update/archive/restore/clone →
    `advanced_training_planning` (personal);
  - `training_series_controller.rb` — preview/create/bulk/stop/cancel_future/
    update_future/split → `advanced_training_planning` (personal);
  - `assessment_sessions_controller.rb` — create/update/publish/restore →
    `advanced_assessments` (personal);
  - `organisations_controller.rb` — update/archive/restore/logo →
    `organisation_management` (organisation); coaches → `club_reporting`
    (organisation).

## Response contract

```json
{
  "error": "This feature requires a subscription",
  "code": "subscription_feature_required",
  "feature": "advanced_training_planning",
  "current_plan": "free",
  "suggested_plan": { "slug": "coach", "name": "Coach", "yearly_price_cents": 1000, "currency": "AUD" }
}
```

## Ordering and separation

1. Authentication.
2. Role/organisation authorization (unchanged).
3. Subscription entitlement.

Admins and curators bypass the subscription gate; a Coach on FREE remains a Coach
for role purposes but cannot use premium Coach operations. The subscriber's
organisation context is taken from the loaded `@organisation`, never from a
parameter.

## Configuration

`BILLING_ENFORCEMENT_ENABLED=true` enables the checks. Default off so a deployment
can ship catalogue and UI before changing existing behaviour; production turns it
on after approval.

## Tests

`test/controllers/api/v1/subscription_enforcement_test.rb`:

- flag off → FREE coach is not blocked (unchanged behaviour);
- flag on → FREE coach gets 403 with the feature and suggested plan, and no row is
  created;
- Coach plan → request succeeds;
- admin → not blocked;
- personal Coach plan does not unlock club management;
- Club plan unlocks it.

## Known gap

`club_reporting` is mapped to one operation (`GET organisations/:id/coaches`).
When reporting features are expanded, add them to the matrix and cover each with a
request spec.
