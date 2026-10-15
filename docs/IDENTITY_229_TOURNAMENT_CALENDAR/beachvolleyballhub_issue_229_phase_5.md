## 7. Phase 5 — Frontend types, API client and reusable UI

**Status: ✅ Implemented.** This phase established the typed tournament API client and
reusable presentation primitives consumed by the tournament directory, detail, and
participation work. Phase 6 builds the `/tournaments` directory/calendar on this
foundation; its calendar-specific behavior is documented separately in
[`beachvolleyballhub_issue_229_phase_6.md`](./beachvolleyballhub_issue_229_phase_6.md).

Extend existing `src/api.ts` rather than using a parallel HTTP client. Add types for
Tournament, Division, Participation, WatchLink, options, filters and pagination. Reuse
auth/error handling, token/private gate and `normalizePaginatedResponse`. Build reusable
tournament cards, badges, date formatting, division chips, filter state and
loading/error/empty UI. Verify actual current file paths in Phase 0.

### Delivered API client and types

Tournament methods are available on the existing `api` object in `src/api.ts`:

```typescript
api.tournaments(filters?: TournamentFilters, request?: { signal?: AbortSignal })
api.tournamentOptions(): Promise<TournamentOptions>
api.tournament(id: number | string): Promise<Tournament>
api.createTournament(data): Promise<Tournament>
api.updateTournament(id, data): Promise<Tournament>
api.archiveTournament(id): Promise<Tournament>
api.publishTournament(id): Promise<Tournament>
api.participateTournament(tournamentId, { role, division_ids }): Promise<Participation>
api.leaveTournament(tournamentId): Promise<void>
```

`api.tournaments` returns `Promise<PaginatedResponse<Tournament>>` and accepts an
optional abort signal. This supports cancellation of superseded directory requests
without introducing a second fetch implementation.

`TournamentFilters` covers search, organiser, scope, division scheme and levels,
location, temporal/publication state, bounded date ranges, participation, and pagination.
Array filters are sent in Rails-compatible repeated-parameter form:

```text
letter_levels[]=A&letter_levels[]=AA
division_numbers[]=1&division_numbers[]=2
```

### Reusable UI and helpers

- `TournamentCard` renders an accessible tournament summary and supports keyboard
  activation when used for navigation.
- `TournamentBadge` renders scope or publication-state badges.
- `DivisionChip` renders division information.
- `TournamentFilterForm` provides shared tournament filters, including selectable letter
  levels.
- The existing loading, error, and empty UI patterns are reused rather than introducing
  parallel state components.
- `src/utils/tournaments.ts` provides tournament URL serialization, month parsing,
  complete-page aggregation, abort detection, and timezone-aware day grouping.

### Relationship to Phase 6

The shared types and client are used by `/tournaments` and `/tournaments/:id`. The
directory intentionally hides manual page controls: Phase 6 requests `per_page=100` and
loads further pages for the bounded result set. It also owns URL-backed list/calendar
state, visible-grid range queries, IANA-timezone/DST-aware event placement, and cancelled
event styling. See the Phase 6 record for its user-facing contract and verification.

### Validation

Focused API serialization coverage verifies normal query parameters, Rails-compatible
array parameters, and abort-signal forwarding. Focused Phase 5/6 frontend validation
passed with changed-file ESLint, `git diff --check`, and 52 Vitest tests spanning API
serialization, URL state, aggregation beyond 100 results, timezone/DST placement,
navigation, and stale-request cancellation.

The full frontend test suite and production build still have unrelated legacy blockers:
an obsolete `test` configuration field in
`src/pages/settings/ConfigurationSettings.test.tsx`, participant-selector expectations
that no longer match rendered controls, and a drill-schema test that references a missing
sibling API schema path.

**Gate:** typed Phase 4 API coverage and focused frontend tests pass. The original
full-suite/build gate remains pending resolution of the unrelated failures above.

**AI prompt — frontend foundation**

In beachvolleyballhub_frontend, inspect current src/api.ts, types, router, auth context,
calendar utilities and design system. Add typed tournament API methods, response
normalization, date/timezone helpers, reusable tournament cards and division badges.
Preserve all existing TrainingCalendar behavior and API conventions. Add Vitest/Testing
Library coverage and mocked API fixtures. Do not build full pages yet. Do not invent
components that already exist.