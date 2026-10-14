## 8. Phase 6 — Tournament directory and calendar

Add `/tournaments` with month calendar and list toggle; search; filters for organiser, scope, division scheme/levels, location and status; event details navigation; and URL-serializable filter state. Use existing `src/utils/calendar.ts` and custom calendar grid where possible, but do not couple to training-session state. Display calendar timezone visibly. Fetch the entire bounded grid range, including leading/trailing days; follow all pagination pages and cancel stale requests when filters change. Distinguish cancelled events visually.

**AI prompt — calendar**

Build a responsive /tournaments page with month/list views using the current React Router, sidebar and calendar utility patterns. Reuse the training calendar's generic grid helpers without changing /calendar behavior. Implement search, combined filters, URL query synchronization, month navigation, timezone display, all-page range fetching, request cancellation, loading/empty/error states, cancelled styling and accessible keyboard interactions. Add unit/integration tests for 100+ events, multi-day spans, overlapping dates, DST, filter races and navigation.

**Gate:** frontend build and integration tests pass; directory shows Phase 4 API data.