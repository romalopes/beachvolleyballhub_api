## 11. Phase 9 — Security, quality and integration testing

Test across both repos:

- Permissions matrix: guest, Account owner, player, coach, curator, admin, real/effective impersonated user.
- Input validation: URLs, text, malformed dates, unknown zones, invalid division codes, duplicated/foreign IDs, forged ownership.
- Lifecycle: upcoming/ongoing/completed, cancelled/archived, restored, delete unused, unlink archived.
- Time: cross-midnight, multi-day, DST spring/fall, international offset, all-day exclusive end.
- Query correctness: overlapping windows, search escaping, combined filters, stable pagination, 100+ records, stale fetch cancellation.
- DB integrity: duplicate self-links, composite FKs, concurrent division edits, organisation deletion restrictions.
- Performance: eager loading, realistic event counts, query plan checks, frontend bundle impact.
- Regression: training calendar, organisations, accounts, profiles, sign-in and test-access gate.

**AI prompt — end-to-end verification**

Run the full backend Minitest suite, frontend lint/typecheck/Vitest/build and existing E2E tests. Add Playwright E2E flows if the project already uses Playwright, otherwise propose a minimal test harness without disrupting CI. Verify guest discovery, admin creation, multi-division editing, self-link, My Tournaments, archive/unlink, 100+ event calendar pagination, timezone boundaries and unchanged training calendar. Report failures with exact reproduction steps; fix only related regressions. Generate docs/tournament_calendar_v2/test_matrix.md and a concise evidence report with commands and results. Do not claim tests passed unless actually executed.

**Gate:** all test suites pass and no new regressions.

## Implementation & verification record (2026-10-16)

### Scope executed in this pass
- **Wrong-path artifact cleanup:** deleted `beachvolleyballproject/src/components/TournamentFilterForm.tsx` (a pseudo-code placeholder created at the workspace-parent path, outside the `beachvolleyballhub` repo; it caused 5 TS errors: missing `TournamentFilters`/`Organisation` types, implicit `any`, undefined `setFilters`) and removed the now-empty `src/` tree.
- **Phase 9 UX fix — active-filter chips show organisation names:**
  - `beachvolleyballhub/src/components/FilterState.tsx`: new optional `organisations?: Organisation[]` prop; chip label `Organisation IDs: 12, 9` → `Organisations: <names>`, with fallback to the raw ID for orgs missing from the list (e.g. stale URLs). The legacy single `organisation_id` chip gets the same treatment.
  - `beachvolleyballhub/src/pages/Tournaments.tsx`: threads the already-loaded `organisations` state into `<FilterState>` (no new API call).
- **New test:** `beachvolleyballhub/src/components/FilterState.test.tsx` — 2 tests: ID→name mapping with unknown-ID fallback, and legacy `organisation_id` mapping.

### Verification (all executed)
- `npx vitest run src/components/FilterState.test.tsx src/pages/Tournaments.test.tsx` → **2 files, 6 tests passed**.
- `npx tsc -b` → **exit 0**, no errors (all previously reported `TournamentFilterForm.tsx` errors are gone with the artifact).
- `npm run build` → **built** (only the pre-existing `SentryFallback.tsx` warning).
- Artifact path `beachvolleyballproject/src/` no longer exists (confirmed).

### Known pre-existing failures NOT caused by this work (tracked)
- ~24 `api.test.ts` failures from `.env.local` `VITE_API_BASE_URL=http://localhost:3001/api/v1` (absolute vs relative URLs).
- ~9 ESLint violations; training/identity/schema backend test failures.
- Full Phase 9 gate (permissions matrix, E2E flows, full backend suite re-run) still pending — this pass covers the active-filter chip fix and repo hygiene only.
