# Recurring Training — API Contract

Base path: `/api/v1`. JSON only. Authentication is the normal session cookie or
bearer token; all new endpoints require a **training manager**
(coach/curator/admin) and return `401` for guests, `403` otherwise.

Feature flag: `RECURRING_TRAINING_ENABLED=false` makes the new endpoints return
`404 { "error": "Recurring training is not available" }`.

Errors use the existing shapes:

```json
{ "errors": ["Name can't be blank"] }        // 422 validation
{ "error": "Training series not found" }     // 404
{ "error": "Forbidden" }                     // 403
```

## Templates

### `GET /training_templates`

Query: `status` (`active`/`archived`), `include_archived=1`, `organisation_id`,
`group_id`, `coach_profile_id`, `q`, `page`, `per_page`.
Default: active only, ordered by name. Response:

```json
{
  "data": [
    {
      "id": 1, "name": "Monday Skills", "description": "…",
      "organisation_id": 2, "group_id": 3, "coach_profile_id": 4,
      "location": "Coogee Beach", "location_detail": "Court 1",
      "location_summary": "Coogee Beach · Court 1",
      "level": "intermediate", "capacity": 12, "duration_minutes": 90,
      "visibility": "shared", "status": "active", "created_by_id": 5,
      "organisation": { "id": 2, "name": "Sydney Beach Volleyball Club" },
      "group": { "id": 3, "name": "Sydney Club squad" },
      "coach_profile": { "id": 4, "display_name": "Maria Silva" },
      "created_by": { "id": 5, "name": "Coach Three" }
    }
  ],
  "meta": { "page": 1, "per_page": 20, "total": 1, "total_pages": 1 }
}
```

### `POST /training_templates`

```json
{
  "training_template": {
    "name": "Sunrise Skills",
    "description": "Early ball control.",
    "organisation_id": 2,
    "group_id": 3,
    "coach_profile_id": 4,
    "location": "Coogee Beach",
    "location_detail": "Court 2",
    "level": "intermediate",
    "capacity": 10,
    "duration_minutes": 75,
    "visibility": "shared",
    "status": "active"
  }
}
```

`201 { "training_template": { … } }`. `created_by` is always the current user.

### `PATCH /training_templates/:id`

Same fields. `200 { "training_template": { … } }`.

### `POST /training_templates/:id/archive` / `restore`

No body. `200 { "training_template": { … "status": "archived" } }`.

### `POST /training_templates/:id/clone`

No body. `201`, copy named `"<name> (copy)"`, active.

## Series

### `POST /training_series/preview`

```json
{
  "training_series": {
    "training_template_id": 1,
    "starts_on": "2026-11-02",
    "ends_on": "2026-11-29",
    "weekdays": ["mon", "wed"],
    "local_start_time": "07:00",
    "duration_minutes": 90,
    "time_zone": "Australia/Sydney",
    "frequency": "weekly",
    "interval": 1,
    "overrides": { "title": "Sunrise Skills", "capacity": 16 }
  }
}
```

Response (`200`; `valid: false` for an invalid draft):

```json
{
  "valid": true,
  "errors": [],
  "warnings": [],
  "time_zone": "Australia/Sydney",
  "total": 8,
  "returned": 8,
  "truncated": false,
  "occurrences": [
    {
      "recurrence_key": "2026-11-02T07:00",
      "local_date": "2026-11-02",
      "local_start_time": "07:00",
      "starts_at": "2026-11-02T07:00:00+11:00",
      "ends_at": "2026-11-02T08:30:00+11:00",
      "duration_minutes": 90,
      "warnings": [],
      "conflicts": [
        {
          "id": 9, "title": "Existing booking", "status": "scheduled",
          "starts_at": "2026-11-01T20:00:00Z",
          "ends_at": "2026-11-01T21:00:00Z",
          "location": "Coogee Beach",
          "reasons": ["coach_overlap", "location_overlap"]
        }
      ]
    }
  ]
}
```

Missing template → `422 { "errors": ["Training template is required"] }`.

### `POST /training_series`

Same body as preview. Persists the series and its occurrences atomically.

```json
{
  "training_series": {
    "id": 10,
    "training_template_id": 1,
    "organisation_id": 2,
    "frequency": "weekly",
    "interval": 1,
    "weekdays": ["mon", "wed"],
    "starts_on": "2026-11-02",
    "ends_on": "2026-11-29",
    "local_start_time": "07:00",
    "duration_minutes": 90,
    "time_zone": "Australia/Sydney",
    "status": "active",
    "generated_through": "2026-11-29",
    "last_generated_at": "2026-10-21T05:00:00.000Z",
    "defaults": { "title": "Monday Skills", "location": "Coogee Beach" },
    "training_template": { "id": 1, "name": "Monday Skills" },
    "organisation": { "id": 2, "name": "Sydney Beach Volleyball Club" },
    "created_by": { "id": 3, "name": "Coach Three" },
    "next_generation_start": "2026-11-30",
    "completed": false
  },
  "generation": { "created_count": 8, "already_present": [], "errors": [] }
}
```

`422` cases include archived template, invalid weekdays/dates, more than 200
occurrences and a window longer than 366 days. Nothing is partially written.

### `GET /training_series`

Query: `training_template_id`, `organisation_id`, `status` (`active`/`stopped`),
`from`/`to` (date overlap), `upcoming=1`, `page`, `per_page`.
`{ "data": [series…], "meta": {…} }`.

### `GET /training_series/:id`

`{ "training_series": { …payload…, "occurrence_count": 8,
"scheduled_count": 8, "cancelled_count": 0, "completed_count": 0,
"draft_count": 0, "next_occurrence_at": "2026-11-02T07:00:00+11:00" } }`

### `GET /training_series/:id/sessions`

Query: `status`, `from`, `to` (ISO timestamps), `page`, `per_page`.
Rows contain the occurrence fields plus `status_label`, `overridden`,
`deletable`, `cancellable` and `coach_profile`.

`404` for an unknown series; `422` for an unknown status or malformed filter.

## Series actions

All actions require a training manager, return `422 { errors }` on validation
failure, and report per-item outcomes rather than silently dropping ids.

### `POST /training_series/:id/bulk_cancel`

```json
{ "session_ids": [101, 102], "reason": "Storm", "notify_participants": true }
```

`200 { "affected_ids": [101], "skipped": [{ "id": 102, "reason": "already_cancelled" }], "errors": [] }`

Skip reasons: `not_in_series`, `already_cancelled`, `not_cancellable`.
Requires at least one id and a reason. When `notify_participants` is true,
reachable participants receive one email; the participant row records
`cancellation_notified_at` so retries are idempotent.

### `POST /training_series/:id/bulk_delete`

```json
{ "session_ids": [103] }
```

`200 { "deleted_ids": [103], "skipped": [], "errors": [] }`

Only **drafts with no participants and no assessments** are deleted. Skip
reasons: `not_in_series`, `not_a_draft`, `has_participants_or_assessments`.

### `POST /training_series/:id/stop`

```json
{ "reason": "Season finished" }
```

`200 { "training_series": { … "status": "stopped", "stopped_reason": "…" }, "changed": true }`

Stopping never cancels or edits existing occurrences; a second call returns
`changed: false`.

### `POST /training_series/:id/cancel_future`

```json
{ "from": "2026-11-16", "reason": "Venue unavailable", "notify_participants": true }
```

`from` is a **local date in the series time zone**. Returns the same shape as
`bulk_cancel`. Later scheduled/draft occurrences are cancelled; earlier ones are
untouched.

### `POST /training_series/:id/update_future`

```json
{
  "effective_from": "2026-11-16",
  "changes": { "title": "Winter Skills", "capacity": 20, "location": "Bondi Beach" },
  "overwrite_overrides": false
}
```

Allowed changes: `title`, `description`, `location`, `location_detail`, `level`,
`capacity`, `coach_profile_id`, `group_id`, `visibility`.

`200 { "updated_ids": [..], "skipped": [{ "id": 9, "reason": "all_fields_overridden" }], "errors": [] }`

By default, a field that an occurrence already overrides is preserved. Changed
fields are recorded in `override_fields`, and the series' `defaults_snapshot` is
updated for future generations. Validation failures roll the whole batch back.

### `POST /training_series/:id/split`

```json
{
  "effective_from": "2026-11-16",
  "reason": "Winter schedule",
  "discard_overrides": false,
  "recurrence": {
    "weekdays": ["thu"],
    "local_start_time": "18:00",
    "duration_minutes": 90,
    "time_zone": "Australia/Sydney",
    "interval": 1,
    "ends_on": "2026-12-31",
    "overrides": { "location": "Bondi Beach" }
  }
}
```

`200`

```json
{
  "training_series": { … old series, ends_on "2026-11-15", status "stopped" … },
  "new_series": { … starts_on "2026-11-16", weekdays ["thu"] … },
  "destroyed_count": 4,
  "generation": { "created_count": 7, "already_present": [], "errors": [] }
}
```

The old series ends the day before the boundary; a new series starts on it and
is generated atomically. Future occurrences with participants or assessments
block the split (`422`, `blockers: [{ "id": 9, "reasons": ["has_participants"] }]`).
Overrides also block it unless `discard_overrides: true`. Old **cancelled**
tombstones are left in place as history.

## Audit

Template and series mutations write `LogService` rows (create/update/archive/
restore/clone, bulk cancel/delete, stop, cancel future, update future, split).

