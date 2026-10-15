## 5. Phase 3 — Search, calendar query and pagination
**Status:** ✅ COMPLETED

Use an overlap predicate for timed events: `starts_at < range_end AND ends_at > range_start`. Include events starting before the visible window. Treat calendar all-day rows according to local date labels and display timezone; test extreme offsets. Provide search across name, organiser name/acronym and location, with parameter binding and escaped LIKE wildcards.

Filters combine with AND; multiple selections within a filter use OR. Support scope, organiser, division scheme, letter levels, division numbers, location, temporal status, `mine`, and publication state (admin only). Use `EXISTS` for child-division filtering to avoid duplicate tournaments and incorrect counts. Stable `(starts_at,id)` ordering. Reuse `{data,meta:{page,per_page,total,total_pages}}`, max page size 100; calendar client must retrieve **all** pages or explicitly signal a result limit.

**AI prompt — queries**

Build an efficient, tested Tournament search/query object following existing PostgreSQL and pagination conventions. Support half-open overlap, multi-day events, timezone-aware all-day calendar matching, escaped text search, AND/OR combined filters, division EXISTS filtering, mine=1, admin-only archived visibility and stable pagination. Prevent N+1 queries. Add Minitest scenarios for DST, distant timezones, boundary equality, duplicate child rows, empty filters, many pages, and query plans. Document all accepted query parameters and semantics.

**Gate:** query tests pass and integration with Phase 2 services verified.