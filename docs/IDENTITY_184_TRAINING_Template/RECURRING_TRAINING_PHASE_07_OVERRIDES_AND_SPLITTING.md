# Phase 7 — Occurrence Overrides, Future Edits and Splitting

**Status:** ✅ Complete
**Date:** 2026-10-21

## Model semantics

- `TrainingSession#override_fields` records the field names that diverged from
  the series defaults, including `starts_at`/`ends_at` when an occurrence is
  moved. It is a JSON object; `overridden?` and `overridden_field?` are the read
  API. Resetting a field to the series value removes its flag.
- `original_starts_at` keeps the intended slot when a coach moves an occurrence;
  `recurrence_key` never changes, so the occurrence remains identifiable.
- Editing one occurrence through the existing training form records an override
  for each changed field and removes it when the field is reset to the series
  default. The comparison uses the template defaults merged with the series
  snapshot, so untouched fields never become false positives.

## Services

### `TrainingSeriesFutureEditor`

- Applies allow-listed fields to future `scheduled` occurrences from a local
  date (`title`, `description`, `location`, `location_detail`, `level`,
  `capacity`, `coach_profile_id`, `group_id`, `visibility`).
- Fields already overridden are preserved unless `overwrite_overrides: true`.
  If every requested field is overridden, the occurrence is reported as
  `all_fields_overridden`.
- Updates `defaults_snapshot` so later generations inherit the change.
- Atomic: a validation error rolls the batch back and leaves the snapshot
  untouched. No actor/organisation scope is invented — the existing role rule
  applies.

### `TrainingSeriesSplitter`

- Boundary is a local date strictly after `starts_on` and on/before `ends_on`.
- The old series ends the day before the boundary and becomes `stopped` with
  `stopped_reason`.
- Eligible future `draft`/`scheduled` occurrences of the old series are destroyed;
  **cancelled tombstones are kept** as history.
- Occurrences with participants, assessments or (unless
  `discard_overrides: true`) overrides block the split. The response is `422`
  with `blockers: [{ id, reasons }]`, and nothing is changed.
- A new series is created from the old template + old defaults snapshot (+
  optional overrides) with the new recurrence, then generated **in the same
  transaction**. A generation failure rolls the split back.

## API

```text
POST /api/v1/training_series/:id/update_future
POST /api/v1/training_series/:id/split
```

See `RECURRING_TRAINING_API.md` for payloads and responses.

## Frontend

`SeriesActionsPanel` adds:

- **Edit future occurrences**: effective date, title/location/level/capacity,
  overwrite toggle.
- **Split series at a new rule**: full `RecurrenceFields` form, reason and
  "allow splitting with overrides" confirmation. Successful splits navigate to
  the new series dashboard.

## Test evidence

```text
bin/rails test test/services/training_series_future_editor_test.rb \
  test/services/training_series_splitter_test.rb
11 tests, 0 failures

bin/rails test test/controllers/api/v1/training_series_controller_test.rb
24 tests, 114 assertions, 0 failures
```

Covered: future-only edits, snapshot update, override preservation/overwrite,
skip-all-overridden, rollback on invalid capacity, empty-change guard, valid
split (old boundary/new weekdays/destroyed count/generated keys), participant and
override blockers, discard-overrides path, invalid boundary/reason.

## Limitations

- Splitting cannot proceed while future occurrences have participants; the coach
  must cancel/withdraw them first. This is deliberate so no registration is
  silently destroyed.
- There is no "edit this and all following" from the single-occurrence form yet;
  that flow lives on the series dashboard.
- A split creates a new series id; bookmarks to the old series remain valid and
  show the shortened, stopped series.
