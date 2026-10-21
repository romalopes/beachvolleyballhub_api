# Architecture Decision Record — Recurring Training

- **Status:** Accepted
- **Date:** 2026-10-21
- **Issue:** IDENTITY-184 (Training Template / recurring training)
- **Related:** `BeachVolleyballHub_Recurring_Training_Implementation_Plan.md`, `RECURRING_TRAINING_PHASE_00_AUDIT.md`

## Context

The API currently exposes one-off `TrainingSession` records only. Coaches need to
reuse a training definition and schedule it on a repeating weekly pattern, while
keeping every occurrence independently editable (coach, location, cancel,
roster). The implementation plan requires templates, series, preview, bulk
operations, overrides and splitting, plus documentation for every phase.

The plan explicitly warns that its candidate names must be checked against the
repository. The audit (`RECURRING_TRAINING_PHASE_00_AUDIT.md`) confirmed:

- `TrainingSession` has `title`, `description`, `starts_at`, `ends_at`,
  `location` (free-text), `status`, `visibility`, `created_by_id`.
- Management is role-based (`ContentAuthorization#require_training_manager!`);
  there is no row-level organisation RBAC for trainings.
- There is no `Location`/`Court` model yet (`docs/FUTURE/Location/...` reserves
  those fields for a later issue).
- `Organisation`, `Group` and `CoachProfile` exist and can be referenced
  without introducing new dependencies.
- The project time zone is UTC by default, so recurrence must carry an explicit
  IANA zone.

## Decision

Adopt **Option A — Template + Series + Session**:

```
Organisation ─┬─ TrainingTemplate ── TrainingSeries ── TrainingSession (0..N)
Group ────────┘         │                  │                │
CoachProfile ───────────┘                  │                └─ participants / attendance / assessments
                                           └─ recurrence + defaults snapshot
```

1. **`TrainingTemplate`** — reusable definition (name, description, org, group,
   coach, location, level, capacity, duration, visibility). Archive instead of
   delete so historical sessions keep a meaningful reference.
2. **`TrainingSeries`** — recurrence rule (weekly, interval, weekdays, local
   start time, IANA time zone, start/end dates) plus an immutable
   `defaults_snapshot` captured at creation. `active`/`stopped` controls
   generation only; stopping never mutates existing sessions.
3. **`TrainingSession`** — the editable occurrence. `training_series_id` is
   nullable, so all existing and manual sessions remain valid with **no
   backfill**. A cancelled occurrence keeps its `recurrence_key`, making it a
   tombstone that regeneration can never resurrect.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| Add recurrence fields directly to `TrainingSession` | Blurs "definition" and "occurrence"; editing one date would rewrite the rule, and reused templates would be impossible |
| Only a series row per pattern (no template) | Fails the reuse/clone/archive user stories; one-off sessions from a template would have nowhere to read defaults from |
| Generate sessions in a background job only | Adds operational surface (queue failures, retries) before the feature is proven; V1 expands synchronously with hard caps |
| Enforce organisation-scoped RBAC for trainings | The codebase has no such rule for trainings today; inventing one would silently change coach access. Documented as a follow-up |

### Consequences

**Positive**

- Existing sessions and their tests are unaffected (no data migration).
- Templates can be reused, cloned and archived independently of schedules.
- Occurrences stay fully editable without corrupting the series definition.
- Cancellation is a tombstone, not a deletion, so history and regeneration
  remain correct.
- The recurrence expander is a pure service and therefore easy to test.

**Negative / trade-offs**

- More tables and joins; series payloads must include a defaults snapshot for
  display.
- Synchronous generation is capped (200 occurrences / 366 days).
- Location stays a string until the Location feature lands.
- Capacity is snapshotted but not enforced when adding participants in V1.

## Semantics (single source of truth)

| Action | Effect |
|---|---|
| Edit template | Affects only series/sessions created **after** the edit |
| Edit one occurrence | Touches that session only; changed fields recorded in `override_fields` |
| Edit future occurrences | Applies selected fields to future `scheduled` sessions, preserving overridden fields unless explicitly overwritten |
| Change the recurrence rule | **Split** the series at a boundary: old series ends before it, a new series starts at it |
| Stop recurrence | `TrainingSeries#status = stopped`; existing sessions untouched |
| Cancel occurrence | `status = cancelled` + reason/actor; row retained as a tombstone |
| Delete occurrence | Only `draft` sessions with no participants/assessments |
| Notifications | Best-effort email after commit, deduplicated per participant |

The dashboard exposes these as separate actions so "stop recurrence" never means
"cancel sessions", and "cancel" never means "delete".

## Schema decisions

- All new columns are nullable or defaulted; no backfill.
- `training_sessions.training_series_id` → `ON DELETE RESTRICT`; a series with
  occurrences cannot be destroyed accidentally.
- Partial unique index
  `(training_series_id, recurrence_key) WHERE training_series_id IS NOT NULL`
  makes generation idempotent and race-safe.
- Check constraint `training_series_id IS NULL OR recurrence_key IS NOT NULL`.
- `weekdays` is a string array validated against `mon..sun`; the expander maps
  it to ISO weekdays internally.
- `defaults_snapshot` (jsonb) is written once at series creation and never
  recomputed from the template.
- `organisation_id`/`group_id`/`coach_profile_id` are schedule metadata with a
  consistency check (group must belong to the organisation when both are set).
  They do not grant or deny access by themselves.

## Phase mapping

| Phase | Deliverable |
|---|---|
| 0 | Audit + this ADR + documentation index |
| 1 | Migrations, `TrainingTemplate`, `TrainingSeries`, `TrainingSession` extensions, model tests |
| 2 | `TrainingRecurrenceExpander`, `TrainingSeriesPreview`, DST/limit tests |
| 3 | `TrainingSeriesGenerator`/`Creator`, idempotency and concurrency tests |
| 4 | Controllers, routes, strong params, feature flag, request tests, API doc |
| 5 | Template + series creation UI with server-backed preview |
| 6 | Series list/detail dashboard, bulk actions |
| 7 | Overrides, update-future, split |
| 8 | Cancellation notifications, dedup, audit logs |
| 9 | Full regression, rollout/rollback, user guide |

## Verification and rollback

- Migrations are additive. Rollback = drop the two new tables and the added
  columns; existing sessions are unaffected.
- `RECURRING_TRAINING_ENABLED=false` disables the new API endpoints without a
  code change (read endpoints included) and returns `404`.
- Deployment order: migrations → API with flag off → enable flag → frontend.
- Every phase records actual test/lint output in its phase document.
