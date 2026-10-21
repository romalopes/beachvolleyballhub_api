# Phase 5 — Frontend Creation Flow

**Status:** ✅ Complete
**Date:** 2026-10-21

## Files

New:

- `src/utils/recurringTraining.ts` — weekday tokens/labels, ISO date helpers,
  schedule labels, override builder, selection summary.
- `src/components/training/RecurrenceFields.tsx` — controlled weekly recurrence
  inputs (start/end, weekdays, local time, duration, interval, IANA zone).
- `src/pages/TrainingTemplates.tsx` — template list with archive/restore/clone
  and "Schedule series" entry points.
- `src/pages/TrainingTemplateFormPage.tsx` — create/edit template with
  organisation/group/coach pickers and template defaults.
- `src/pages/TrainingSeriesFormPage.tsx` — template picker, recurrence, series
  overrides, server-backed preview and create.

Updated:

- `src/api.ts` — template/series/preview types and client methods; occurrence
  fields; `training_series_id` calendar filter.
- `src/App.tsx` — routes under `ManagerRoute`:
  `/training/templates`, `/training/templates/new`,
  `/training/templates/:id/edit`, `/training/series`, `/training/series/new`,
  `/training/series/:id`.
- `src/pages/Training.tsx` — Templates/Series buttons and a `training_series_id`
  filter banner with "Clear filter".
- `src/App.css` — recurrence fields, weekday pills, preview rows, template
  action row, table and summary styles.

## Behaviour

- Template list defaults to active rows; "Show archived templates" toggles
  `include_archived=1`. Archived templates cannot be scheduled (button
  disabled; the API also refuses).
- The series form is pre-filled from `?template_id=`; choosing a template copies
  its duration and location defaults, but the title stays blank so occurrences
  use the template name unless the coach overrides it.
- "Preview dates" calls `POST /training_series/preview` and renders the total,
  the first 10 dates in the **series** time zone, DST warnings and conflicts.
  Preview never writes.
- "Create series" is disabled only when the last preview was invalid; the API
  remains the authority and reports transactional errors.
- Creating a series navigates to its dashboard.

## Directory layout (tournament-style)

The training directory now mirrors the tournaments directory:

- **`/training` is the single directory.** `/calendar` redirects to
  `/training?view=calendar`, and the sidebar has one Training entry instead of
  Training + Calendar.
- A **List / Calendar toggle** in the header switches views without leaving the
  page. Calendar mode adds period navigation (previous / Today / next) and a
  **Month / Week** range toggle; list mode renders a card grid.
- State lives in the URL (`view`, `range`, `cursor`, `status`, `mine`,
  `training_series_id`), so any view is linkable and survives refresh.
- The left **Filters** aside (status, "only sessions I participate in") and the
  card grid reuse the tournament `.filter-form` / `.form-group` layout and the
  `.card` anatomy via new `training-*` classes.
- Templates and series directories use the same header-actions + filter-aside +
  card-grid layout, with `TrainingTemplateCard` and `TrainingSeriesCard`.

New/updated components:

- `src/components/training/TrainingSessionCard.tsx`
- `src/components/training/TrainingCalendarGrid.tsx`
- `src/components/training/TrainingFilterForm.tsx`
- `src/components/training/TrainingTemplateCard.tsx`
- `src/components/training/TrainingSeriesCard.tsx`
- `src/pages/Training.tsx` (rewritten), `TrainingTemplates.tsx`,
  `TrainingSeries.tsx` (rewritten)
- `TrainingCalendar.tsx` deleted; its grid lives in `TrainingCalendarGrid`.

## Test evidence

New frontend tests:

- `src/utils/recurringTraining.test.ts` — 6 tests.
- `src/components/training/SeriesOccurrenceTable.test.tsx` — 3 tests.
- `src/pages/TrainingSeriesFormPage.test.tsx` — 3 tests (preview, create
  payload/navigation, invalid preview).
- `src/pages/TrainingTemplateFormPage.test.tsx` — 2 tests (create payload,
  server validation errors).
- `src/pages/Training.test.tsx` — 6 tests (list cards, list/calendar toggle,
  calendar navigation, month/week range, manager-only New Training, status
  filter).

```text
npx vitest run src/utils/recurringTraining.test.ts \
  src/components/training/SeriesOccurrenceTable.test.tsx \
  src/pages/TrainingSeriesFormPage.test.tsx \
  src/pages/TrainingTemplateFormPage.test.tsx \
  src/pages/Training.test.tsx
20 tests passed

npm test          # 94 files, 923 tests passed
npm run lint      # clean
npm run build     # built (pre-existing Sentry/chunk-size warnings only)
npx tsc --noEmit  # clean
```

## Limitations

- No calendar drag-and-drop for occurrences; individual editing stays on the
  existing training form.
- The time-zone list is a curated set plus the browser zone, not every IANA
  identifier.
- Preview conflicts are advisory (same coach/location string); court-level
  conflicts wait for the Location feature.
