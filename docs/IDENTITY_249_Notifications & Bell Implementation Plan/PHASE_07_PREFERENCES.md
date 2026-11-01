# Phase 7 — Preferences

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §9
**Status:** Complete.

## 1. Delivered

| Layer | Artefact |
|---|---|
| Storage | `notification_preferences` table (Phase 1) |
| Model | `app/models/notification_preference.rb` |
| API | `GET|PATCH /api/v1/notification_preferences` |
| UI | `src/components/NotificationPreferencesPanel.tsx` (rendered on `/account`) |
| Enforcement | `Notifications::Publisher` consults `preference.event_enabled?(event_type)` before writing a row |

## 2. Defaults and semantics

| Setting | Default | Meaning |
|---|---|---|
| `in_app_enabled` | `true` | Master switch for in-app notifications |
| `email_enabled` | `false` | Reserved for Phase 8; off until email is enabled |
| `email_cadence` | `"immediate"` | `immediate` / `daily` / `weekly` / `none` (DB CHECK) |
| `muted_event_types` | `[]` | Per-event-type mutes, e.g. `["training.invited"]` |

A **missing row means defaults**: the API materialises one on first read/write, so no backfill is
needed for existing accounts.

**Preference is enforced server-side**, not just hidden in the UI: a muted or in-app-disabled
account receives no row at all (asserted in `publisher_test.rb`).

## 3. UI

`NotificationPreferencesPanel` on the Account page:
- "Show notifications in the app" switch;
- "Also email me about important updates" switch (disabled cadence control until email is on);
- "Email frequency" select;
- a "Mute specific updates" fieldset with a checkbox per event type.

Each control saves on change and reports success/failure without losing form state.

## 4. Mandatory/operational notifications

The plan asks to preserve mandatory operational communications. In this release **no event is
treated as un-mutable**: all current event types are user-relevant updates (training changes,
membership decisions), and `in_app_enabled` is a user-facing preference. If a future mandatory
service message (e.g. security) is added, it should bypass preferences by design and be documented
here — that decision was **not** taken unilaterally in this change.

## 5. Tests

Backend (`test/models/notification_preference_test.rb`, `test/controllers/api/v1/notification_preferences_controller_test.rb`,
`test/services/notifications/publisher_test.rb`):
- defaults, uniqueness, cadence + mute-array validation;
- materialised defaults over HTTP; persistence of switches/mutes; 422 on invalid cadence;
- muted / in-app-disabled accounts receive nothing.

Frontend (`src/components/NotificationPreferencesPanel.test.tsx`): load, save email switch, save
mute, surface load failure.

## 6. Exit criteria

| Criterion | Result |
|---|---|
| Account-scoped preferences with category/channel defaults | ✅ |
| Authenticated GET/PATCH API | ✅ |
| Settings UI | ✅ |
| Cross-account isolation | ✅ (scoped through `Current.user.account`; unique per account) |
| Delivery planning honours disabled channels | ✅ enforced in the publisher |
