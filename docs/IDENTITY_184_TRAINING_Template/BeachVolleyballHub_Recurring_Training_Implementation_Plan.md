# BeachVolleyballHub — Recurring Training Implementation Plan

**Status:** Proposed implementation plan; validate against current repositories before coding  
**Date:** 2026-10-21  
**Repositories:** [Rails API](https://github.com/romalopes/beachvolleyballhub_api) · [React frontend](https://github.com/romalopes/beachvolleyballhub_frontend)  
**Related work:** Location management (organisation, group, training session, tournament; court/meeting-point specification)

> **Verification note:** This document is an implementation blueprint, not a verified line-by-line audit of the current repositories. A direct repository source fetch was unsuccessful in this environment. Model names, associations, API routes, and filenames below are candidates; Phase 0 requires the coding agent to inspect the actual code and revise them before any migration.

## Implementation status

| Phase | Status | Document |
|---|---|---|
| 0 — Audit & ADR | ✅ Complete | [`RECURRING_TRAINING_PHASE_00_AUDIT.md`](RECURRING_TRAINING_PHASE_00_AUDIT.md) · [`RECURRING_TRAINING_PHASE_00_ADR.md`](RECURRING_TRAINING_PHASE_00_ADR.md) |
| 1 — Data model | ✅ Complete | [`RECURRING_TRAINING_PHASE_01_DATA_MODEL.md`](RECURRING_TRAINING_PHASE_01_DATA_MODEL.md) |
| 2 — Recurrence & preview | ✅ Complete | [`RECURRING_TRAINING_PHASE_02_RECURRENCE_AND_PREVIEW.md`](RECURRING_TRAINING_PHASE_02_RECURRENCE_AND_PREVIEW.md) |
| 3 — Generation | ✅ Complete | [`RECURRING_TRAINING_PHASE_03_GENERATION.md`](RECURRING_TRAINING_PHASE_03_GENERATION.md) |
| 4 — API & authorization | ✅ Complete | [`RECURRING_TRAINING_PHASE_04_API_AND_AUTHORIZATION.md`](RECURRING_TRAINING_PHASE_04_API_AND_AUTHORIZATION.md) |
| 5 — Frontend creation | ✅ Complete | [`RECURRING_TRAINING_PHASE_05_FRONTEND_CREATION.md`](RECURRING_TRAINING_PHASE_05_FRONTEND_CREATION.md) |
| 6 — Series dashboard | ✅ Complete | [`RECURRING_TRAINING_PHASE_06_SERIES_DASHBOARD.md`](RECURRING_TRAINING_PHASE_06_SERIES_DASHBOARD.md) |
| 7 — Overrides & splitting | ✅ Complete | [`RECURRING_TRAINING_PHASE_07_OVERRIDES_AND_SPLITTING.md`](RECURRING_TRAINING_PHASE_07_OVERRIDES_AND_SPLITTING.md) |
| 8 — Notifications & audit | ✅ Complete | [`RECURRING_TRAINING_PHASE_08_NOTIFICATIONS_AUDIT_OBSERVABILITY.md`](RECURRING_TRAINING_PHASE_08_NOTIFICATIONS_AUDIT_OBSERVABILITY.md) |
| 9 — QA & rollout | ✅ Complete | [`RECURRING_TRAINING_PHASE_09_QA_AND_ROLLOUT.md`](RECURRING_TRAINING_PHASE_09_QA_AND_ROLLOUT.md) |

See [`README.md`](README.md) for the documentation map and verified audit findings.

**Phase 0 adaptations (verified against the repositories):**
- Training management is role-based (`content_manager?`); there is no row-level organisation RBAC for trainings. `organisation_id`/`group_id` are schedule metadata in V1.
- No `Location`/`Court` model exists; `location` stays a string and `location_detail` is added. `location_id`/`court_id` are deferred to the Location feature.
- Time zone is UTC by default, so series carry an explicit IANA `time_zone`.
- New columns are additive; existing sessions require no backfill.

## 1. Objective and scope

Enable an authorised coach or curator to create a reusable training definition, schedule repeated training occurrences, view/manage the resulting series, selectively cancel/delete sessions, and update a single occurrence or all eligible future occurrences. Preserve existing one-off training flows and registrations.

### User stories

1. As a coach, I can save a reusable template with name, description, organisation, optional group, coach, level, gender/category if applicable, capacity, location and optional court/meeting point.
2. As a coach, I can schedule a template weekly on one or more weekdays, with start/end dates, local start time, duration and timezone.
3. As a coach, I can preview generated dates and identify conflicts before saving.
4. As a coach, I can edit/cancel one session without changing its siblings.
5. As a coach/curator, I can view all occurrences in a series, filter and select individual occurrences, and cancel/delete selected ones in a single operation.
6. As a coach/curator, I can stop recurrence, cancel all future sessions, or update eligible future sessions, with explicit confirmation and participant notification policy.
7. As an attendee, I can see the accurate status/location/time for each occurrence, and my registration is not silently destroyed.
8. As a curator, I can act only within the organisation/group scope granted by existing RBAC rules.

### Out of scope for V1

- Arbitrary iCalendar RRULE expressions, monthly ordinal rules, infinite recurrence and complex cross-timezone itineraries.
- Automatic booking/payment refunds unless the existing application already implements them.
- Google Calendar two-way sync.
- Replacing the existing TrainingSession domain model or building a parallel registration system.

## 2. Architecture decision

**Recommended:** three conceptual models, subject to Phase 0 verification:

```text
Organisation ─┬─ TrainingTemplate ── TrainingSeries ── TrainingSession (0..N)
              │          │                  │                 │
              └─ Group? ─┘                  └─ recurrence     └─ registrations/attendance
                     CoachProfile?                definition        + overrides
Location ─────────────────────────────── template defaults / occurrence snapshots
```

- **TrainingTemplate:** reusable defaults; can also produce one-off sessions. Ownership must match existing account/coach/organisation semantics.
- **TrainingSeries:** immutable-or-versioned recurrence definition and default snapshot at series creation; stores lifecycle and generation horizon.
- **TrainingSession:** actual independently editable occurrence. `training_series_id` nullable for existing/manual sessions. Existing participant, attendance, content and status associations remain intact.

**Simplification option:** If current code already has a training template abstraction, reuse it. If templates are not independently useful, a `TrainingSeries` with its own default fields may be simpler than introducing two new tables. Make this decision explicitly after Phase 0, not before.

### Candidate fields (adapt to actual schema)

| Entity | Candidate fields | Notes |
|---|---|---|
| `training_templates` | `name`, `description`, `organisation_id`, `group_id`, `coach_profile_id`, `location_id`, `location_detail` or `court_id`, `level`, `capacity`, `duration_minutes`, `active` | Align naming, levels and location detail with existing models; do not duplicate organisation/location structures. |
| `training_series` | `training_template_id`, `organisation_id` (only if needed for scope), `created_by_account_id`, `frequency`, `interval`, `weekdays`, `starts_on`, `ends_on`, `local_start_time`, `duration_minutes`, `time_zone`, `status`, `generated_through`, `defaults_snapshot` | For V1 allow `weekly`, `interval=1`, multiple weekdays; consider daily only if needed. |
| `training_sessions` | `training_series_id` nullable, `recurrence_key` or `original_starts_at`, `is_series_exception`/`override_fields` | Keep existing timestamps, location, coach, registration and status fields. |

Use PostgreSQL foreign keys and appropriate indexes. Enforce uniqueness for `(training_series_id, recurrence_key)` on generated sessions, with `recurrence_key` representing the *original intended occurrence* rather than mutable actual start time. Do not regenerate manually moved/cancelled occurrences. A cancelled occurrence must remain as a tombstone or exclusion record to prevent reappearance.

### Template and occurrence semantics

- Editing a **template** changes defaults for *new* series and sessions; existing series and occurrences do not change automatically.
- Editing **one occurrence** changes only that session and marks its overridden fields.
- Editing **future occurrences** applies only to selected fields and eligible occurrences; show a count and preserve manual overrides by default. For recurrence rule changes, prefer **split series** at the effective date (old series ends before boundary; new series begins there) while retaining history and stable registration references.
- Editing **all occurrences** must never rewrite completed, attended or past sessions without an explicit privileged migration workflow.
- Stop generating ≠ cancel already generated sessions ≠ delete sessions. Present these as separate actions.

## 3. Critical business rules

### Access control

- Reuse existing RBAC and organisation/group membership policies; never trust `organisation_id`, `coach_profile_id` or session IDs sent by the browser.
- Coach: create/manage only sessions they own or are explicitly authorised to manage; curator/admin: scope to permitted organisations/groups. Define how independent groups work.
- Verify every selected ID belongs to the series and falls within the caller's permitted scope; reject or clearly report forbidden IDs, never silently modify unrelated sessions.
- Enforce policies in controller *and* service/query layers used by background jobs.

### Cancellation, deletion and audit

- **Cancel** is default for published sessions, particularly those with participants, payments or attendance. Preserve history, registration references, cancellation reason and actor.
- **Hard delete** only drafts/unpublished occurrences with no dependent data, after server-side validation. Consider soft-delete if existing application conventions require it.
- Bulk operations return affected/skipped IDs and reasons. Prefer atomicity per operation or explicitly document partial-success semantics.
- Log who changed what, when, why and how many sessions were affected; retain before/after values as permitted by existing audit/privacy policies.
- Participant notifications should be asynchronous, deduplicated and sent only after committed changes; define whether cancellation is visible immediately even if email fails.

### Time, recurrence and conflicts

- Store an IANA timezone (`Australia/Sydney` for local Coogee training unless the location differs); persist actual UTC timestamps for occurrences.
- Generate from **local wall-clock date/time** using Rails timezone facilities, converting each date separately to UTC so daylight-saving shifts do not move the intended local time.
- Define DST ambiguity/nonexistent-time policy (e.g. reject and ask user to choose a valid local time); test spring and autumn transitions.
- Define inclusive end date and deterministic weekday encoding (`mon`...`sun` or ISO 1..7).
- Limit generated horizon and total occurrences (configurable, e.g. 12 months / 200 sessions initially), plus preview limits and validation.
- Check duplicate occurrence keys, overlapping coach assignments, and optional location/court conflicts; start with warnings unless the existing business rules mandate blocking.
- Recurrence generation must be idempotent under concurrent requests/retries using DB uniqueness and transactional upsert/create patterns.

### Locations

- Use the location model introduced by the separate Location issue; avoid new free-text location tables.
- Organisation/group may provide a default location; template may override it; occurrence snapshot may override template. Make the precedence explicit.
- Court/meeting-point specification should use the canonical location-subdivision model if implemented; otherwise use a temporary detail field with a documented migration path.
- If location support is not yet merged, keep recurrence work decoupled via a nullable reference and feature-gate map UI.

## 4. Phased implementation

### Phase 0 — Repository audit and ADR (mandatory)

**Inspect API:** `db/schema.rb` or structure SQL, `app/models`, training controllers/services/serializers, routes, policies, memberships, coach and group models, notifications, jobs, tests, and existing location implementation.  
**Inspect frontend:** training routes/pages/forms, API client/hooks, shared types, authorisation guards, calendars, date/time inputs, tests.  
**Deliverables:** actual file inventory, current relationship diagram, data preservation risks, confirmed model naming, architecture decision record (ADR), migration order, acceptance test mapping.

**AI prompt 0 — audit (run with both repositories open):**

```text
You are the lead engineer for BeachVolleyballHub. Read the current API and frontend repositories, not just their READMEs. Locate the actual TrainingSession, organisation/group, coach/account, RBAC, location, registration, attendance and notification implementations. Produce a file-by-file architecture audit with citations to paths and key methods. Check whether reusable training templates or recurrence already exist. Compare (A) TrainingTemplate + TrainingSeries + TrainingSession with (B) TrainingSeries + TrainingSession; choose the smallest design that supports reusable defaults, bulk management and single-occurrence overrides. Identify breaking changes and missing dependencies, especially the Location feature. Do not edit code. Output docs/architecture/recurring_training_ADR.md and a revised implementation checklist based on the real schema. Flag unknowns instead of inventing model names.
```

**Human checkpoint:** approve ADR and relationship ownership before migrations.

### Phase 1 — Data model and backward-compatible migrations

1. Add template/series tables only as justified by ADR; foreign keys, validation constraints and indexes.
2. Add nullable `training_series_id` and stable occurrence key to existing sessions.
3. Preserve all current records as standalone sessions; do **not** automatically backfill them into series.
4. Add lifecycle states consistent with existing status enums, avoiding enum ordinal changes that would corrupt data.
5. Add minimal audit/cancellation fields or reuse existing audit mechanism.
6. Validate `db:migrate`, schema consistency, rollback on test DB, and query plans for series lookups.

**AI prompt 1 — models/migrations:**

```text
Implement Phase 1 using the approved ADR and actual Rails conventions. Create backward-compatible PostgreSQL migrations, models, associations, validations and indexes for recurring training. Do not rename or drop existing training fields. Preserve standalone sessions with nullable series association. Enforce uniqueness of original occurrence keys within a series. Use existing organisation, coach, location, group and RBAC model names. Add model and migration tests for existing data, nullability, foreign keys and uniqueness. Show migration and rollback commands and summarize each changed file. Do not implement APIs yet.
```

### Phase 2 — Recurrence domain service and preview

1. Implement pure recurrence expansion service, e.g. `TrainingRecurrence::Expand`, returning local dates and UTC start/end timestamps.
2. Support weekly weekday selection, interval, inclusive date range, duration and IANA timezone.
3. Validate maximum span/count, invalid weekdays, date ordering, nonexistent DST local times and duplicates.
4. Build dry-run preview with total count, first/last dates, conflicts and warnings.
5. Add deterministic service tests for DST, leap years, month boundaries, start/end inclusivity and reruns.

**AI prompt 2 — recurrence:**

```text
Using the approved schema, implement a pure, deterministic recurrence expansion service for weekly recurring training. Generate occurrence keys based on the original local schedule and calculate each occurrence's UTC timestamps using its IANA timezone. Include a preview mode that performs no writes, a configurable generation limit and explicit DST invalid/ambiguous-time handling. Return structured validation errors and conflict warnings. Add thorough unit tests including Australia/Sydney DST boundaries, multiple weekdays, inclusive end dates and zero-result rules. Keep scheduling logic out of controllers and ActiveRecord callbacks.
```

### Phase 3 — Transactional generation and idempotency

1. Implement `TrainingSeries::GenerateOccurrences` service with transaction boundaries and DB uniqueness protection.
2. Snapshot template/series defaults into each TrainingSession using existing session creation validations and required associations.
3. Persist original occurrence key and avoid resurrecting cancelled/deleted exceptions.
4. Handle retries/concurrency; do not duplicate participants or trigger multiple notifications.
5. Return `created`, `already_present`, `skipped` and `errors` counts with IDs.
6. Initially generate finite schedules synchronously only if safe; use a background job for larger ranges.

**AI prompt 3 — generator:**

```text
Implement a transactional, idempotent TrainingSeries occurrence generator using the Phase 2 recurrence service and existing TrainingSession creation conventions. Preserve snapshot values and all existing callbacks/business rules. Protect against concurrent generation using PostgreSQL constraints. Repeated calls must not duplicate sessions, and cancelled/moved occurrences must never be recreated at the original slot. Return a structured result and test concurrent calls, failures, retries and existing standalone training compatibility. Avoid creating participant registrations automatically unless already supported and explicitly approved.
```

### Phase 4 — Rails API and authorisation

**Proposed endpoints** (adapt to existing route conventions):

```text
GET    /training_templates
POST   /training_templates
GET    /training_templates/:id
PATCH  /training_templates/:id
POST   /training_series/preview
GET    /training_series
POST   /training_series
GET    /training_series/:id
PATCH  /training_series/:id
GET    /training_series/:id/sessions
POST   /training_series/:id/bulk_cancel
POST   /training_series/:id/bulk_delete
POST   /training_series/:id/stop
POST   /training_series/:id/update_future
```

- Use existing API namespace/version and JSON serializers.
- Scope lists and mutations by existing policies.
- Preview must be authorised and should not expose other coaches' private schedules beyond approved conflict information.
- Bulk payload: explicit `session_ids`, `reason`, and optional notification flag; avoid accepting a naked `all=true` without explicit server-side scope/date confirmation.
- For large operations, support idempotency key or job status if needed; provide per-item errors.
- Update OpenAPI/API docs if the project uses them.

**AI prompt 4 — API:**

```text
Implement authenticated recurring training REST endpoints following the project's actual route, serializer, controller and policy patterns. Support template CRUD, recurrence preview, series creation/list/detail, occurrence listing, bulk cancel, restricted bulk delete, stop recurrence and update future. Every query and mutation must enforce organisation/group/coach RBAC and verify session ownership. Provide structured errors, pagination, request specs for success/forbidden/cross-organisation access, and API documentation. Use service objects for domain changes. Do not hard-delete sessions with registrations, attendance or payments.
```

### Phase 5 — Frontend creation and preview

1. Add template management (create/edit/clone/archive) and one-off session-from-template flow.
2. Add recurrence form: name, organisation/group/coach, levels, capacity, location/court, weekdays, local start time, duration, start/end dates, timezone.
3. Preview occurrences and warnings before confirmation; show total count and date list/calendar.
4. Reuse existing form validation, components, API client, error handling and RBAC display rules.
5. Ensure location selector/map reuses the Location feature's components and remains optional if unavailable.

**AI prompt 5 — frontend creation:**

```text
Implement reusable training template and recurring series creation UI in the current BeachVolleyballHub React/TypeScript frontend. Inspect and reuse existing training forms, routing, API hooks, validation, level selectors, organisation/group/coach selectors and location widgets. Add weekly weekday recurrence controls, timezone-aware date/time inputs and a server-backed preview with conflict warnings and total count. Provide loading, empty, error and success states, keyboard accessibility, responsive layouts and tests. Do not assume backend endpoint shapes; use the approved API contract.
```

### Phase 6 — Series dashboard and selective bulk actions

1. Add series list with filters for organisation, group, coach, status, date range and template.
2. Add series detail with occurrences table/calendar, status, location, registration counts and overrides.
3. Add checkboxes, select visible/select future/select all eligible (with clear scope), and individual selection.
4. Provide separate **Cancel selected**, **Delete eligible drafts**, **Stop recurrence**, **Cancel future**, and **Edit future** actions.
5. Confirmation modal: operation, selected count, protected count, notification consequences and reason.
6. On completion, display affected/skipped/error counts and refresh state; do not imply all succeeded if partial.

**AI prompt 6 — dashboard:**

```text
Build a recurring training series management dashboard in the existing frontend design system. Provide paginated occurrence listing, filters, multi-select, select-future and select-all-eligible controls, and separate cancel/delete/stop actions. Show registration/attendance protection, clear confirmation dialogs, reasons and server-returned per-item results. Prevent accidental action on sessions outside the active series or scope. Add component and integration tests for selection, permission-hidden actions, partial failures and refreshed results.
```

### Phase 7 — Overrides, edit-future and splitting series

1. Implement one-off edit without mutating template or siblings.
2. Record overridden fields; distinguish moved session's original recurrence key from new timestamp.
3. For edits to future series defaults, show preview/diff and preserve overrides by default.
4. If weekday/time recurrence changes, split at effective date rather than rewriting history; define handling of already registered future occurrences before implementation.
5. Preserve cancelled exceptions when recalculating generation.

**AI prompt 7 — edits:**

```text
Implement individual occurrence overrides and safe edit-future behaviour. Retain original recurrence keys, registration/attendance relationships and audit history. For schedule-rule changes, implement a split-series strategy at a selected local date, with a preview showing retained, modified, cancelled and newly created occurrences. Never silently move registered participants or overwrite manual changes. Add request, service and UI tests for edits, cancellation exceptions and daylight-saving transitions.
```

### Phase 8 — Notifications, observability and audit

1. Reuse existing email/notification infrastructure; notify affected participants of meaningful cancellations/time/location changes.
2. Enqueue only after transaction commit; deduplicate by action/occurrence/recipient.
3. Add structured logs and error monitoring for generation, bulk actions and notification failures, using existing Sentry/OTel configuration if present.
4. Record actor, series, operation, affected IDs, reason and timestamps; avoid logging unnecessary personal information.

**AI prompt 8 — operational features:**

```text
Integrate recurring training operations with the project's existing notification, audit and observability conventions. Notify registered participants after committed cancellations or significant changes, with idempotent delivery and failure retries. Add structured metrics/logs for generated counts, conflicts, failed jobs, bulk cancellations and authorisation denials. Ensure no duplicate email on retry. Write tests for transaction rollback, after-commit enqueueing and notification deduplication.
```

### Phase 9 — QA, rollout and documentation

1. Test current one-off session flows and every existing training endpoint for regressions.
2. Test coach/curator/admin cross-organisation access, independent groups, unlinked profiles, invalid ownership and mixed-ID bulk requests.
3. Test DST and recurrence edge cases, retry/concurrency, pagination, registrations, notifications and accessibility.
4. Deploy additive migrations first, then API behind a feature flag, then frontend.
5. Pilot with one organisation/coach and small date ranges; monitor duplicate/conflict/error rates.
6. Document user-facing workflows and admin recovery steps.
7. Rollback by disabling feature and stopping generation; retain existing generated sessions and audit history unless a separately reviewed data cleanup is required.

**AI prompt 9 — release readiness:**

```text
Review the complete recurring training feature against the approved ADR and acceptance criteria. Run API test suite, frontend tests, typecheck, lint and build using repository-native commands. Test existing one-off training workflows, cross-organisation RBAC, concurrency, DST, cancellation with registrations and rollback. Produce a release checklist, feature-flag rollout, monitoring plan, known limitations and user/admin documentation. Report actual test results and unresolved failures; do not claim success for commands not executed.
```

## 5. Suggested API request/response contracts (illustrative)

### Preview request

```json
{
  "training_template_id": 42,
  "recurrence": {
    "frequency": "weekly",
    "interval": 1,
    "weekdays": ["tue", "thu"],
    "starts_on": "2026-11-03",
    "ends_on": "2027-02-25",
    "local_start_time": "07:00",
    "duration_minutes": 90,
    "time_zone": "Australia/Sydney"
  }
}
```

### Preview response

```json
{
  "total": 34,
  "occurrences": [
    {
      "recurrence_key": "2026-11-03T07:00:00[Australia/Sydney]",
      "local_date": "2026-11-03",
      "starts_at": "2026-11-02T20:00:00Z",
      "ends_at": "2026-11-02T21:30:00Z",
      "warnings": []
    }
  ],
  "warnings": [],
  "truncated": true
}
```

> Sample `total` and `truncated` are illustrative; calculate them server-side. The API may choose a simpler stable key format; never use a mutable actual start timestamp as the unique identity.

### Bulk cancel request

```json
{
  "session_ids": [101, 103, 107],
  "reason": "Beach closed due to weather",
  "notify_participants": true
}
```

### Bulk result

```json
{
  "affected_ids": [101, 103],
  "skipped": [{"id": 107, "reason": "already_cancelled"}],
  "errors": []
}
```

## 6. Acceptance criteria

- [x] Existing standalone TrainingSessions remain functional and do not require a template or series.
- [x] An authorised coach can create a reusable template and a finite weekly series with multiple weekdays.
- [x] Preview shows correct local times across Sydney DST boundaries and does not write sessions.
- [x] Creating/retrying a series never duplicates occurrences.
- [x] A manually moved or cancelled occurrence is not recreated by regeneration.
- [x] Coach can edit/cancel one occurrence without changing others.
- [x] Coach/curator can select noncontiguous sessions and cancel them in one action.
- [x] Bulk deletion rejects protected/published/registered/attended sessions according to policy.
- [x] Stop recurrence does not unexpectedly cancel existing sessions.
- [x] Edit future preserves history and manual overrides; rule changes use approved split semantics.
- [ ] Every endpoint enforces actual organisation/group/coach scope server-side. **(V1 mirrors the existing role-based training rule; row-level organisation RBAC is a documented follow-up.)**
- [ ] Location and court selection reuse canonical Location work. **(No Location/Court model exists yet; `location` + `location_detail` are stored, `location_id`/`court_id` deferred.)**
- [x] Notifications are after-commit, deduplicated and retriable.
- [x] Audit logs record bulk actions and actor/reason.
- [x] API tests, frontend tests, lint, typecheck and build pass; rollout and rollback documented.

## 7. Dependencies, risks and decisions to resolve

| Decision / risk | Proposed default | Owner/checkpoint |
|---|---|---|
| Existing training schema differs | Audit and adapt; never invent associations | Phase 0 |
| Is a separate template table necessary? | Yes if templates reused across series/one-off sessions; otherwise simplify | ADR |
| Location feature incomplete | Nullable location + reuse canonical feature later | Phase 0 / Location issue |
| Series owner vs organisation/group permissions | Reuse current RBAC policy; test cross-scope | Phase 0/4 |
| Registered future sessions after schedule changes | Preview and explicit handling; preserve registrations | Phase 7 |
| Existing payments/booking semantics | Block destructive operations; integrate refunds only if present | Phase 0/6 |
| Session deletion semantics | Cancel published; delete unused drafts only | Phase 4/6 |
| Indefinite recurrence | Not in V1; finite horizon and max count | Product owner |
| Timezone and DST | IANA timezone and local-time expansion | Phase 2 |
| Automatic conflict resolution | Warnings first; blocking only for established rules | Product owner |

## 8. Suggested implementation sequence and commands

Run commands from the correct repository root, adjusting to its package manager and test conventions discovered in Phase 0:

```bash
# API: inspect first
bundle exec rails routes | grep -i training
bundle exec rails db:migrate:status
bundle exec rails test        # only if Rails test is the configured suite
# or: bundle exec rspec      # only if RSpec is configured

# Frontend: inspect package.json scripts first
cat package.json
npm run lint                 # if script exists
npm run build
npm test                     # if script exists
```

Do not run production migrations or delete records without a reviewed migration plan and backup. Create one pull request per coherent phase (or small adjacent phases), require green CI and manual review for migrations, RBAC and destructive actions.

## 9. Definition of done

Feature is complete only when a coach can create a reusable template, preview and create a weekly series, manage occurrences as a group, cancel selected sessions safely, preserve registrations/history, and stop or edit future schedules with predictable results—without regressing existing one-off training or exposing cross-organisation data.
