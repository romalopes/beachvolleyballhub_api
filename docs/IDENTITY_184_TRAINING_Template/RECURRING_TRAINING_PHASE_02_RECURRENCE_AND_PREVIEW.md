# Phase 2 — Recurrence Expansion & Preview

**Status:** ✅ Complete
**Date:** 2026-10-21

## Files

- `app/services/training_recurrence_expander.rb`
- `app/services/training_series_preview.rb`
- `test/services/training_recurrence_expander_test.rb`
- `test/services/training_series_preview_test.rb`

## Expansion algorithm

- Day tokens `mon..sun` map to ISO weekdays (`Date#cwday`). End date inclusive.
- `interval` is anchored on the **week containing `starts_on`** (Monday-based),
  so interval 2 means "the starting week, then every second week".
- Optional `from:`/`through:` windows are clipped to the series' own
  `starts_on..ends_on`; generation and dashboard slices cannot escape it.
- `recurrence_key` is `YYYY-MM-DDTHH:MM` in the series' **local** wall clock and
  never changes when a session is moved.
- Hard caps: 366-day window, 200 occurrences. Exceeding either returns an error
  rather than truncating silently.

## Time-zone policy

Each local date is converted with TZInfo:

| Situation | Behaviour |
|---|---|
| Normal local time | Converted with the period's UTC offset |
| Spring-forward gap (e.g. Sydney 2026-10-04 02:30) | Request rejected with the date and zone |
| Fall-back overlap (e.g. Sydney 2026-04-05 02:30) | Earlier instant chosen (larger UTC offset) + warning |

`ends_at` is `starts_at + duration` (elapsed time). A session that crosses a DST
boundary keeps its real length; the wall clock may appear to shift.

## Preview service

`TrainingSeriesPreview.new(template:, series:).call` returns:

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
      "conflicts": []
    }
  ]
}
```

- Display cap: 60 occurrences (`truncated: true` when `total` is larger).
- Conflicts are **advisory**: overlapping `draft`/`scheduled` sessions with the
  same coach (effective defaults) or the same location string. Each conflict
  carries `reasons: ["coach_overlap"]` / `["location_overlap"]`. At most 5 per
  occurrence. Cancelled/completed sessions are ignored.
- The preview performs **no writes** (`assert_no_difference` in tests).

## Test evidence

```text
bin/rails test test/services/training_recurrence_expander_test.rb
12 runs, 35 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/services/training_series_preview_test.rb
7 runs, 31 assertions, 0 failures, 0 errors, 0 skips
```

Covered: multi-weekday expansion, inclusive end date, interval anchoring,
sub-windows, empty windows, span/occurrence caps, spring-forward error,
fall-back warning + earlier instant, invalid series, coach/location conflicts,
cancelled conflicts ignored, truncation.

## Limitations

- `location` conflicts compare free-text strings; they are a hint, not a court
  reservation. Court-level conflicts arrive with the Location feature.
- No cross-time-zone “follow the coach” scheduling; each series has one zone.
- Preview conflict queries use the whole preview window; very long lists are
  capped before querying sessions.
