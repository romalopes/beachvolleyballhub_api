# Phase 1 — Data Model

**Status:** ✅ Complete
**Date:** 2026-10-21

## Scope

Add the recurring-training persistence layer without touching existing data.

## Migrations

| Migration | Contents |
|---|---|
| `20261021000001_create_training_templates.rb` | `training_templates` with name, description, nullable org/group/coach/creator, location + detail, level, capacity, duration (default 90), visibility, status; check constraints |
| `20261021000002_create_training_series.rb` | `training_series` with template FK (restrict), nullable organisation/creator, weekly frequency, interval, `weekdays` string array, start/end dates, local start time, IANA time zone, status, `generated_through`, `defaults_snapshot` jsonb, `last_generated_at`, `stopped_at`; check constraints |
| `20261021000003_add_recurring_training_fields_to_training_sessions.rb` | nullable series/template/org/group/coach/cancelled_by references, capacity, level, location_detail, `recurrence_key`, `original_starts_at`, `override_fields`, cancellation fields; partial unique index and check constraint |

All migrations are additive. Existing `training_sessions` rows remain valid:
`training_series_id` is `NULL`, so `recurrence_key` is not required and the
partial unique index does not apply to them.

### Key database guards

- `index_training_sessions_on_series_and_recurrence_key` — **unique**, partial on
  `training_series_id IS NOT NULL AND recurrence_key IS NOT NULL`. This is the
  race-safe guard that makes generation idempotent.
- `training_sessions_series_requires_recurrence_key` — a series occurrence must
  carry the intended slot.
- `training_series_weekdays_present` / `training_series_weekdays_valid` —
  non-empty and restricted to `mon..sun`.
- `training_series_ends_on_after_starts_on`, duration/interval/capacity positive.
- FKs: series/template use `ON DELETE RESTRICT`; org/group/coach/creator use
  `ON DELETE NULLIFY`; a session's `organisation_id`/`group_id` never owns
  access.

## Models

- **`TrainingTemplate`** — validations (name, status, visibility, duration,
  capacity), group/organisation consistency, `#defaults_for_series`,
  `#location_summary`, active/archived predicates, `restrict_with_error` for
  referenced series/sessions.
- **`TrainingSeries`** — weekday normalisation (downcase, strip, uniq),
  supported weekdays, date order, IANA zone validation, template/organisation
  consistency, `#defaults`, `#next_generation_start`, `#completed?`,
  active/stopped predicates, `restrict_with_error` for occurrences.
- **`TrainingSession`** — optional series/template/org/group/coach/cancelled_by
  associations, recurrence-key presence and per-series uniqueness, capacity
  validation, template/series consistency, `#series_occurrence?`,
  `#overridden?`, `#overridden_field?`, `#cancellable?`,
  `#deletable_occurrence?`, `#mark_cancelled!`, `for_series`/`starting_from`/
  `scheduled` scopes.

## Fixtures and tests

- `test/fixtures/training_templates.yml` — shared, private and archived templates.
- `test/fixtures/training_series.yml` — active multi-weekday series, private
  weekly series, stopped series.
- `test/models/training_template_test.rb`
- `test/models/training_series_test.rb`
- `test/models/training_session_test.rb` — new recurring cases appended.

## Test evidence

```text
cd beachvolleyballhub_api
bin/rails test test/models/training_template_test.rb \
  test/models/training_series_test.rb test/models/training_session_test.rb

Running 59 tests in parallel using 10 processes
59 runs, 223 assertions, 0 failures, 0 errors, 1 skips
```

The single skip is the pre-existing placeholder
`visible_to excludes private drafts from their participants`.

## Limitations carried forward

- No `Location`/`Court` FK; `location` + `location_detail` only.
- `capacity` is not enforced on participant creation.
- Organisation/group columns are schedule metadata, not an authorization scope.
- Phase 8 adds `training_session_participants.cancellation_notified_at`.
