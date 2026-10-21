# Phase 3 — Generation & Series Creation

**Status:** ✅ Complete
**Date:** 2026-10-21

## Files

- `app/services/training_series_generator.rb`
- `app/services/training_series_creator.rb`
- `test/services/training_series_generator_test.rb`
- `test/services/training_series_creator_test.rb`

## `TrainingSeriesGenerator`

Creates `TrainingSession` rows from an expanded series.

### Idempotency

- A session is identified by `(training_series_id, recurrence_key)`.
- Existing keys are loaded in one query and skipped as `already_present`.
- The partial unique index is the race-safe backstop; `RecordNotUnique` is
  reported as `already_present`, never as a 500.
- A **cancelled** occurrence keeps its key, so regeneration cannot resurrect it.

### Generation horizon

- Default window: `series.next_generation_start..series.ends_on`, where
  `generated_through` is exclusive.
- `generated_through` advances only when the run has **no errors**. A failed run
  is retried from the same date.
- Explicit `from:`/`through:` windows support top-ups and tests; they are clipped
  to the series' own start/end dates.

### Session snapshot

Generated occurrences are `scheduled` and take:
`title` (fallback: template name), description, organisation, group, coach,
location + location_detail, level, capacity, visibility, template id, series id,
`recurrence_key`, `original_starts_at = starts_at`, empty `override_fields`, and
`created_by = series.created_by` (audit only).

No participants, focuses, drills or assessments are created automatically.

### Atomicity

- Default `atomic: true`: any invalid occurrence rolls the whole run back and
  leaves `generated_through` untouched.
- `atomic: false` keeps successful occurrences and reports errors, but still
  does **not** advance `generated_through`, so a retry revisits the failures.

## `TrainingSeriesCreator`

- Builds the series from a template + recurrence attributes.
- Copies `template.defaults_for_series` and applies only allow-listed overrides
  (`title`, description, org, group, coach, location, location_detail, level,
  capacity, visibility). Unknown keys are dropped.
- Uses the template organisation/duration/visibility when not provided, and
  `Time.zone.name` when no IANA zone is supplied.
- Persists the series and generates occurrences in one transaction. If
  generation fails, the series is rolled back as well.
- `TrainingSeriesCreator.build_series(...)` returns the same unsaved object used
  for preview, so preview and persistence cannot drift.

## Test evidence

```text
bin/rails test test/services/training_series_generator_test.rb \
  test/services/training_series_creator_test.rb

15 runs, 91 assertions, 0 failures, 0 errors, 0 skips
```

Covered: full generation, snapshot fields, horizon advance, double-run
idempotency, cancelled tombstones, two-window top-up, atomic rollback,
non-atomic error reporting, isolation from manual sessions, override snapshot,
template immutability, time-zone fallback, invalid recurrence, generation
rollback, unsaved build for preview, unknown override filtering.

## Limitations

- Generation is synchronous and capped at 200 occurrences.
- No automatic background top-up scheduler in V1; the generation service is
  ready to be called by one.
- Capacity is copied but not enforced on participant creation.
