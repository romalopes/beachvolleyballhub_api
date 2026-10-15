## 8. Phase 6 — Tournament directory and calendar

**Status: ✅ Implemented and verified with focused frontend tests.** The directory now
provides URL-backed filters and month/list view state, fetches every bounded API
page, cancels superseded requests, renders multi-day events in their declared
timezone, and visually distinguishes cancelled tournaments. The broader frontend
suite/build still has unrelated legacy test/configuration failures that are outside
this phase.

Add `/tournaments` with month calendar and list toggle; search; filters for organiser, scope, division scheme/levels, location and status; event details navigation; and URL-serializable filter state. Use existing `src/utils/calendar.ts` and custom calendar grid where possible, but do not couple to training-session state. Display calendar timezone visibly. Fetch the entire bounded grid range, including leading/trailing days; follow all pagination pages and cancel stale requests when filters change. Distinguish cancelled events visually.

**AI prompt — calendar**

Build a responsive /tournaments page with month/list views using the current React Router, sidebar and calendar utility patterns. Reuse the training calendar's generic grid helpers without changing /calendar behavior. Implement search, combined filters, URL query synchronization, month navigation, timezone display, all-page range fetching, request cancellation, loading/empty/error states, cancelled styling and accessible keyboard interactions. Add unit/integration tests for 100+ events, multi-day spans, overlapping dates, DST, filter races and navigation.

### Delivered behavior

- `/tournaments` supports Calendar and List tabs, month navigation, filter/reset
  controls, and navigation to `/tournaments/:id` from pointer or keyboard activation.
- The URL is the source of truth for `month` (`YYYY-MM`), non-default `view=list`,
  scalar filters, comma-delimited `letter_levels`/`division_numbers`, and `mine=1`.
  This makes filtered or selected-month directory URLs bookmarkable and shareable.
- Calendar requests cover the entire rendered month grid, including leading and
  trailing days. The client sets a bounded range and requests `per_page=100`, then
  follows every additional page rather than silently truncating calendars larger than
  100 tournaments.
- Each new directory request owns an `AbortController`; changing URL-backed state
  aborts the previous request and stale results cannot replace current data.
- Calendar placement derives date keys in the event's own IANA timezone. This covers
  multi-day spans, overlapping tournaments, and daylight-saving transitions without
  changing the existing training `/calendar` behavior.
- Cancelled tournaments have a distinct visual treatment. Tournament cards are focusable
  controls and support keyboard activation.
- API array filters are serialized in Rails-compatible repeated-parameter form:
  `letter_levels[]=A&letter_levels[]=AA` and
  `division_numbers[]=1&division_numbers[]=2`.

### Validation completed

- Focused ESLint checks for changed frontend files passed.
- `git diff --check` passed.
- Focused Vitest suites passed (**52 tests**), including URL serialization, 101+ result
  aggregation, visible-grid ranges, month navigation, detail navigation, stale-request
  cancellation, API serialization, multi-day/overlap placement, and DST behavior.

### Remaining verification

Manual browser verification against the running API remains appropriate for seeded
tournaments: month transitions, filter combinations, URL restoration, list/calendar
switching, cancelled and multi-day display, and detail navigation.

The full frontend test suite and production build were not clean at this point because
of unrelated existing problems: `ConfigurationSettings.test.tsx` still uses the obsolete
`test` configuration field rather than `use_test_email`; participant-selector assertions
do not match the current controls; and
`src/services/drillSchema/schemaConsistency.test.ts` points to a missing sibling API
schema path. These items are not changes introduced by Phase 6.

**Gate:** focused Phase 6 tests pass and the directory consumes Phase 4 API data. The
original full-suite/build gate remains pending resolution of the unrelated failures above.