# Phase 6 — Series Dashboard, Bulk Cancel/Delete, Stop

**Status:** ✅ Complete
**Date:** 2026-10-21

## Backend

New services:

- `TrainingSeriesCanceller` — cancels explicit ids only; keeps the tombstone
  key; skips `not_in_series`, `already_cancelled`, `not_cancellable`; requires
  a reason; optionally enqueues notifications after the transaction.
- `TrainingSeriesDeleter` — deletes only `draft` occurrences with no
  participants and no assessments; reports every skipped id.
- `TrainingSeriesStopper` — sets `status = stopped`, `stopped_at`,
  `stopped_reason`; never touches occurrences; idempotent.
- `TrainingSeriesFutureCanceller` — resolves ids from a local boundary and
  delegates the actual rules to the canceller.

Migration `20261021000004_add_stopped_reason_to_training_series.rb` adds the
auditable reason (a text column). Migration `…000005` adds
`cancellation_notified_at` to participants (used in Phase 8).

Controller actions (all manager-only):

```text
POST /api/v1/training_series/:id/bulk_cancel
POST /api/v1/training_series/:id/bulk_delete
POST /api/v1/training_series/:id/stop
POST /api/v1/training_series/:id/cancel_future
```

Responses carry `affected_ids`/`deleted_ids`, per-item `skipped` reasons and
`errors`; validation failures return `422`. No action accepts "all ids" — the
client must send the ids it selected.

## Frontend

- `SeriesOccurrenceTable` — checkbox selection, cancels/completed rows locked,
  status/coach/location/flags, edits and cancellations visible.
- `TrainingSeriesDetail` — schedule summary (status, dates, weekdays, time zone,
  counts, next occurrence), status filter, occurrence table, selection count and
  clear action.
- `SeriesActionsPanel` — collapsible forms for cancel-selected, delete-drafts,
  stop-recurrence and cancel-future, with reason, notification opt-in and
  per-action result messages.
- `TrainingSeries` list — upcoming/all toggle, status filter, template name,
  schedule label, date range, next occurrence.

Selection is presentation only; the API re-validates every id.

## Test evidence

```text
bin/rails test test/services/training_series_canceller_test.rb \
  test/services/training_series_deleter_test.rb \
  test/services/training_series_stopper_test.rb
17 tests, 0 failures

bin/rails test test/controllers/api/v1/training_series_controller_test.rb
24 tests, 114 assertions, 0 failures
```

Service coverage: cancellation scope/tombstones/skip reasons/no-notify default,
single email per reachable participant, draft-only deletion, participant guard,
foreign-id safety, stop idempotency/occurrence preservation, boundary-based
future cancellation.

Frontend: dashboard/table/action-panel tests in Phases 5 and 7; full `npm test`
suite 921 passing, lint/build clean.

## Known behaviour

- `bulk_delete` will usually delete nothing in a generated series because
  generated occurrences are `scheduled`, not drafts. It exists for manually
  created drafts and for future workflows.
- Cancelling is irreversible through the API; a cancelled occurrence cannot be
  regenerated (tombstone).
- Deleting a draft is the only destructive action, and it refuses any row with
  history.
