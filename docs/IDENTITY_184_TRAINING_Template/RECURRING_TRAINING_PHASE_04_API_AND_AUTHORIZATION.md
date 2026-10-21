# Phase 4 — API & Authorization

**Status:** ✅ Complete (core endpoints; bulk actions arrive in Phases 6–7)
**Date:** 2026-10-21

## Authorization

- Every new endpoint includes `ContentAuthorization` and calls
  `require_training_manager!` (`Current.user.content_manager?` — coach, curator
  or admin). This is exactly the existing training rule; `created_by` is audit
  only and is never consulted.
- Guests receive `401`, players `403`, matching the existing training API.
- `RecurringTrainingAuthorization` gates the **new** endpoints on
  `RECURRING_TRAINING_ENABLED` (default `true`). Disabled endpoints return
  `404 { "error": "Recurring training is not available" }`.
  Existing `/training_sessions` endpoints are deliberately **not** gated.
- Organisation/group ids are validated as references (and the model checks
  group/organisation consistency) but do not grant access. Row-level
  organisation RBAC remains a documented follow-up.

## Routes

```text
GET    /api/v1/training_templates
POST   /api/v1/training_templates
GET    /api/v1/training_templates/:id
PATCH  /api/v1/training_templates/:id
POST   /api/v1/training_templates/:id/archive
POST   /api/v1/training_templates/:id/restore
POST   /api/v1/training_templates/:id/clone

POST   /api/v1/training_series/preview
GET    /api/v1/training_series
POST   /api/v1/training_series
GET    /api/v1/training_series/:id
GET    /api/v1/training_series/:id/sessions
```

There is intentionally **no DELETE** for templates or series. Templates are
archived; series are stopped (Phase 6), not destroyed.

## Templates controller

- Index defaults to `active`; `include_archived=1` (or an explicit `status`)
  includes archived rows. Filters: `organisation_id`, `group_id`,
  `coach_profile_id`, `q` (name/description ILIKE). Paginated `{data, meta}`.
- `create` always stamps `created_by = Current.user`; a client-supplied creator
  is not permitted.
- `clone` creates an active copy named `"<name> (copy)"`; the original and its
  series are untouched.
- `archive`/`restore` change `status` only.

## Series controller (core)

- `preview` builds the **same** unsaved series `create` would save
  (`TrainingSeriesCreator.build_series`) and returns
  `TrainingSeriesPreview`'s payload. No writes. Validation problems are a
  `200` with `valid: false`, because previewing an invalid draft is expected.
- `create` refuses archived templates (`422`), creates the series and generates
  occurrences in one transaction, and returns
  `{ training_series, generation: { created_count, already_present, errors } }`
  with `201`.
- `index` filters `status` (series `active`/`stopped`), `training_template_id`,
  `organisation_id`, `from`/`to` (overlap) and `upcoming=1`; newest start first.
- `show` adds occurrence counts by status and the next scheduled occurrence.
- `sessions` lists occurrences (paginated, max 100 per page) with
  `status`, `from` and `to` (timestamps). Each row carries `overridden`,
  `deletable` and `cancellable` flags.

## Training sessions API changes

- Calendar payload adds `location_detail`, `coach_profile_id`,
  `training_series_id`, `training_template_id`, `recurrence_key`.
- Detail payload adds `capacity`, `level`, org/group/coach ids,
  `original_starts_at`, `override_fields`, cancellation fields, plus
  `training_series`, `training_template`, `coach_profile`, `organisation`,
  `group` summaries.
- Strong params permit org/group/coach/capacity/level/location_detail.
  `training_series_id` and `recurrence_key` stay **server-controlled**.
- Index accepts `training_series_id` as a filter.
- Duplicate `(series, recurrence_key)` now maps to
  `"This occurrence already exists in the series"`.

## Test evidence

```text
bin/rails test test/controllers/api/v1/training_templates_controller_test.rb \
  test/controllers/api/v1/training_series_controller_test.rb
30 runs, 126 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/controllers/api/v1/training_sessions_controller_test.rb
52 runs, 205 assertions, 0 failures, 0 errors, 0 skips
```

Covered: list/filter/404, create/update, archive/restore, clone, role and guest
guards, feature flag, preview no-writes and invalid input, missing/archived
template, transactional create, override snapshot, index filters, show metrics,
occurrence filters/pagination, unknown series, and the updated one-off session
contract.

## Notes

- `index` for templates excludes archived rows by default; the SPA's toggle must
  pass `include_archived=1`.
- The preview response is a top-level object (`valid`, `total`, `occurrences`,
  …) rather than wrapped in `preview`, matching the plan's contract.
- See `RECURRING_TRAINING_API.md` for request/response examples.
