# Phase 5 — Training and organisations

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §8 (Phase 5)
**Status:** Complete.

## 1. Training workflow

**Controller:** `app/controllers/api/v1/training_sessions_controller.rb`

- `update` takes a **pre-update snapshot** (`status`, `starts_at`, `ends_at`, current participant
  account ids) via a new private `notification_snapshot` helper, before `assign_attributes`.
- `persist` emits `Notifications::WorkflowEvents.training_changed(...)` **after** `save` succeeds and
  the record is reloaded. `create` emits nothing (there is no prior state to compare against).

Resulting transitions:

| Transition | Event type | Recipients |
|---|---|---|
| Status becomes `cancelled` | `training.cancelled` | Session participants (via `PlayerProfile#account`) |
| `starts_at` / `ends_at` changed | `training.rescheduled` | Session participants |
| A participant is added | `training.invited` | **Only** the newly added account |
| Any other edit | *(none)* | — |

**Recurring training:** a series occurrence is just a `TrainingSession`, so a single-occurrence edit
emits for that occurrence only, and each occurrence carries its own `training:<id>:…` event key.
Bulk series operations (`cancel_future`, `update_future`) go through the same per-session saves, so
each affected session produces its own deduplicated notification rather than one broadcast.

## 2. Organisation membership workflow

**Controller:** `app/controllers/api/v1/organisations_controller.rb`

| Action | Emit | Recipients |
|---|---|---|
| `join` (when `status == "pending"`) | `membership.requested` | Active owner/administrators (`organisation_memberships.active.manageable`) |
| `approve_member` | `membership.approved` | The requester |
| `reject_member` (when an **approver** rejects) | `membership.rejected` | The requester |

An **auto-active** join (organisation does not require approval) sends nothing — there is no
approver action to route. A requester **withdrawing their own** pending request sends nothing.

## 3. Group membership workflow

**Controller:** `app/controllers/api/v1/groups_controller.rb` — the same three hooks with the group
as the target (`Group#owners` as approvers, `/groups/:id` as the target path).

## 4. Privacy and fanout guarantees

- Recipients are derived from real membership/participation rows at event time.
- The actor is excluded where notifying them would be noise.
- **No hierarchy propagation:** a club/group action never notifies national/state parents.
- Target paths are internal routes only.

## 5. Tests

- `test/services/notifications/workflow_events_test.rb` — recipient correctness for every transition.
- Existing request suites for the three controllers continue to pass unchanged (verified: the
  failure set in `organisations_controller_test.rb` / `groups_controller_test.rb` is identical with
  and without this change — see Phase 11).

## 6. Deferred within this phase

| Plan item | Status |
|---|---|
| `training_session.location_changed` as a distinct type | Deferred — a location-only edit currently produces no event; adding a dedicated type is additive in Phase 6 |
| Training **registration** events (`training_registration.*`) | Deferred — BVH models participation as `TrainingSessionParticipant` edited by coaches, not a public registration flow, so the plan's event names have no counterpart yet |
| Account-claim review events | Deferred to Phase 6 (see that report) |
| Organisation **invitation** email | Out of scope — invitations are a separate existing email flow |

## 7. Exit criteria

| Criterion | Result |
|---|---|
| Training cancel/reschedule/participant events | ✅ |
| Organisation + group membership request/decision events | ✅ |
| Correct recipients; actor excluded where appropriate | ✅ |
| No duplicate events | ✅ `event_key` + `create_or_find_by!` |
| No unrelated parent-organisation notifications | ✅ |
