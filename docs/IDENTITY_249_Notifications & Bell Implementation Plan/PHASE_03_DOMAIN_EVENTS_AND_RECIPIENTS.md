# Phase 3 — Domain events and recipients

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §6
**Status:** Complete (dispatcher + recipient resolution; the event registry is populated in Phase 5).

## 1. Delivered

### `app/services/notifications/publisher.rb`

The single entry point for creating in-app notifications. Callers describe an event once; the
publisher owns the cross-cutting rules:

- **recipient preference filtering** — an account that muted the event type (or disabled in-app
  notifications) gets no row;
- **idempotency** — `create_or_find_by!(event_key:)` against the unique `(account_id, event_key)`
  index, so replaying a transition never duplicates a recipient's row;
- **created-flag reporting** — each result carries `created:`, so a later email/push channel can
  act only on genuinely new notifications.

It deliberately performs **no authorization**: choosing recipients is the caller's responsibility
and belongs beside the workflow that knows who is affected.

### `app/services/notifications/workflow_events.rb`

The "who is told what, when" rules (the plan's `RecipientsResolver` equivalent), as a namespaced
module of module functions:

| Function | Purpose |
|---|---|
| `training_changed(training, actor:, previous:)` | Classifies a training update as **cancelled** / **rescheduled** / **participant added** by comparing the pre-update snapshot, then notifies only the affected participants |
| `membership_requested(container, membership, actor:)` | Routes a pending join request to the **approvers** |
| `membership_decided(container, membership, actor:, decision:)` | Tells the **requester** the outcome |
| `participant_accounts(training)` | Resolves recipients through `PlayerProfile#account`; a profile with no account is simply not a recipient |
| `approver_accounts(container)` | Organisation → active owner/administrators; Group → owners |
| `container_path(container)` | Safe internal route for the target |

## 2. Design rules honoured

- **Triggered from controllers after a successful commit**, never from model callbacks — the plan
  explicitly forbids scattering `after_save` hooks across models.
- **Only meaningful transitions emit.** `training_changed` compares old vs new status/times/participants
  and emits nothing for a no-op update.
- **The actor is never notified of their own action** where that would be noise (e.g. a requester
  withdrawing their own request; an auto-active join sends nothing).
- **Stable event keys** derived from record ids + transition, e.g.
  `training:<id>:cancelled-<updated_at>`, `organisation:<id>:membership:<id>:approved`.
- **No hierarchy broadcast** — a national/state parent is never notified about club/group activity.

## 3. Tests

`test/services/notifications/publisher_test.rb`:
- one row per recipient, `created` reported;
- replay is idempotent and reports `created: false`;
- duplicate recipients deduplicated;
- muted / in-app-disabled accounts receive nothing;
- actor, target and metadata carried onto the row; nil recipients ignored.

`test/services/notifications/workflow_events_test.rb`:
- reschedule / cancellation notify participants and nobody else;
- adding a participant notifies **only** the newly added account;
- a session with no account-bearing participants notifies nobody;
- an unchanged session emits nothing;
- a pending join request notifies organisation approvers (not the requester);
- an approval notifies only the requester, with the correct target path (organisation and group).

Run:

```bash
bin/rails test test/services/notifications/publisher_test.rb \
               test/services/notifications/workflow_events_test.rb
```

Result: **passing** (see Phase 11).

## 4. Event registry status

| Plan event | Status |
|---|---|
| `training_session.rescheduled` | ✅ implemented (`training.rescheduled`) |
| `training_session.cancelled` | ✅ implemented (`training.cancelled`) |
| training participant added | ✅ implemented (`training.invited`) |
| `organisation.membership_requested` | ✅ implemented (`membership.requested`) |
| `organisation.membership_approved` | ✅ implemented (`membership.approved`) |
| `organisation.membership_rejected` | ✅ implemented (`membership.rejected`) |
| group equivalents | ✅ implemented (same event types, group target) |
| `training_session.location_changed` | ⏳ deferred — treated as a reschedule today; a distinct type can be added in Phase 6 |
| `training_session.reminder`, registrations, claims, tournaments, assessments, analysis, comments, announcements | ⏳ deferred (Phases 6/8) — no speculative callbacks added |

## 5. Exit criteria

| Criterion | Result |
|---|---|
| Centralized dispatcher | ✅ `Notifications::Publisher` |
| Recipients resolved from real models/permissions | ✅ |
| Only post-commit, meaningful transitions | ✅ |
| Actor excluded where appropriate | ✅ |
| Dedupe + stable keys | ✅ |
| No notification to unrelated parent organisations | ✅ |
