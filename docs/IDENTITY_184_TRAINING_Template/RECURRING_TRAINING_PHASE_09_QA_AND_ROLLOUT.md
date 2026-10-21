# Phase 9 — QA, Rollout & Acceptance

**Status:** ✅ Complete
**Date:** 2026-10-21

## Test matrix

| Layer | Coverage | Result |
|---|---|---|
| Models | Template/series validations, session recurrence invariants | ✅ |
| Recurrence | Multi-weekday, interval, inclusive end, sub-windows, caps, DST gap/overlap | ✅ |
| Preview | No writes, totals, truncation, coach/location conflicts, invalid input | ✅ |
| Generation | Snapshot fields, idempotency, tombstones, two-window top-up, atomic rollback | ✅ |
| Bulk/stop | Explicit ids only, skip reasons, participant guard, idempotent stop | ✅ |
| Overrides/split | Override preservation/overwrite, snapshot update, blockers, atomic split | ✅ |
| Controllers | Templates/series CRUD, preview, create, list/show/sessions, all actions, 401/403/404/422, feature flag | ✅ |
| Jobs/mailer | Delivery, retry idempotency, accountless skip, non-cancelled skip | ✅ |
| Frontend | Utils, recurrence form, preview, template form, occurrence table, detail/actions | ✅ |

### Targeted backend run

```text
bin/rails test test/models/training_* test/services/training_* \
  test/controllers/api/v1/training_* test/jobs/training_session_cancellation_job_test.rb

217 runs, 929 assertions, 0 failures, 0 errors, 1 skips
```

The single skip is the pre-existing placeholder
`visible_to excludes private drafts from their participants`.

### Frontend run

```text
npm test         # 94 files, 923 tests passed
npm run lint     # clean
npm run build    # built; only pre-existing Sentry/chunk-size warnings
npx tsc --noEmit # clean
```

### Full backend suite (regression)

```text
bin/rails test
1435 runs, 5805 assertions, 15 failures, 4 errors, 1 skips
```

All recurring-training tests pass. The failures/errors are in untouched areas
and were present before this feature:

- `TournamentDivisionServiceTest` / tournaments integration (date-sensitive
  fixture data),
- `Api::V1::GroupsControllerTest` (fixture membership counts),
- `Api::V1::HealthControllerTest` (environment-specific diagnostics),
- `Api::V1::OrganisationsControllerTest` (membership lifecycle expectations).

No file in those areas was modified by this work (`git status` shows only
training/recurring files, routes, schema and docs).

### RuboCop

```text
bin/rubocop app/controllers/api/v1/training_* app/services/training_* \
  app/models/training_* app/jobs/training_session_cancellation_job.rb \
  app/mailers/training_sessions_mailer.rb
22 files inspected, no offenses detected
```

## Deployment order

1. `bin/rails db:migrate` (five additive migrations; no backfill).
2. Deploy the API with `RECURRING_TRAINING_ENABLED=false`.
3. Smoke test existing `/training_sessions` list/create and `/up`.
4. Deploy the SPA.
5. Set `RECURRING_TRAINING_ENABLED=true` (or unset) and restart.
6. Verify: create template → preview → create series → dashboard → cancel one
   occurrence with notification → stop recurrence.

Feature flag behaviour: false → new endpoints return
`404 { "error": "Recurring training is not available" }`. Existing one-off
training endpoints are never gated.

## Rollback

- Fast: set `RECURRING_TRAINING_ENABLED=false`; the SPA's new pages will show
  API errors, existing training pages keep working.
- Code rollback: revert the SPA deploy; API endpoints remain available but
  unused.
- Schema rollback: `bin/rails db:rollback STEP=5` drops the two new tables and
  the added columns. This destroys series data by design; take a backup first.
  One-off sessions are unaffected because all added columns are nullable/defaulted.

## Acceptance criteria

| Requirement | Status |
|---|---|
| Reusable template with org/group/coach/level/capacity/location | ✅ (`location` + `location_detail`; FK to Location deferred) |
| Weekly recurrence, multiple weekdays, start/end, local time, duration, zone | ✅ |
| Preview dates and conflicts before saving | ✅ (advisory coach/location conflicts) |
| Edit/cancel one occurrence without changing siblings | ✅ (existing form edit; cancel via bulk endpoint with one id) |
| Series dashboard, filter, select, bulk cancel/delete | ✅ (server reports per-item skips) |
| Stop recurrence, cancel future, update future with confirmation + notification policy | ✅ |
| Attendee sees accurate status/location/time; registration not silently destroyed | ✅ (tombstones; split refuses participant-bearing rows) |
| Organisation/group-scoped curator authority | ⚠️ Role-based only, matching existing training rules; row-level org RBAC is a documented follow-up |

## Known limitations

- No training-level gender/category field; the current domain does not model one
  for trainings. Level is a free-text field like `PlayerProfile#level`.
- No Location/Court FK; location conflicts are string-based hints.
- Capacity is stored/displayed but not enforced on participant creation.
- Generation is synchronous, capped at 200 occurrences / 366 days.
- Split refuses future occurrences with participants/assessments/overrides.
- No background top-up scheduler; the generator is ready to be called by one.
- Single-occurrence edits and time moves record overrides, so future bulk edits
  and splits respect them; there is no separate per-occurrence exceptions list
  beyond the dashboard flags.
- Contract tests for the recurring endpoints live in request tests; there is no
  OpenAPI artefact.
