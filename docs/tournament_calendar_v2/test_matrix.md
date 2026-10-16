# Tournament Calendar V2 — Test Matrix

All numbers below were produced by commands executed on 2026-10-16 in this workspace.

## Frontend (`beachvolleyballhub/`)

| Gate | Command | Result |
| --- | --- | --- |
| Unit/integration tests | `npx vitest run` | **895/895 passed, 89 files** |
| Types | `npx tsc -b` | **0 errors** |
| Lint | `npx eslint .` | **0 problems** (was 9 errors + 1 warning) |
| Build | `npm run build` | **✓ built** (only pre-existing SentryFallback warning) |

Tournament-specific suites: `Tournaments.test.tsx` (4), `admin/Tournaments.test.tsx` (2), `FilterState.test.tsx` (2), `MyTournaments.test.tsx`, `TournamentForm` tests, `api.test.ts` tournaments client tests (46 total in file).

## Backend (`beachvolleyballhub_api/`, `RAILS_ENV=test`)

| Suite | Command | Result |
| --- | --- | --- |
| Tournament models + services + controllers | `rails test test/models/tournament_*_test.rb test/services/tournament_*_test.rb test/controllers/api/v1/tournament*_test.rb` | **all green** (was 107+ incl. new `organisation_ids` query + integration tests) |
| Organisation model (delete guard) | `test/models/organisation_test.rb` | **55 runs, 0 failures/errors** |
| Full suite | `rails test` | 1263 runs, 4994 assertions — tournament areas fully green; **14 failures + 16 errors + 1 skip remain, all in non-tournament features** (admin configurations, groups, health/email, registrations/sessions, organisation owner-leave, AppSetting) — pre-existing, tracked separately |

## Flow coverage mapping (plan §11 matrix)

- **Permissions matrix:** `tournaments_integration_test.rb` (12 request tests: guest/401, member/403, admin OK), `TournamentManagementAuthorization` covered via controller tests.
- **Input validation:** service tests (`TournamentCreateService`, `TournamentTime` timezone/all-day parsing, `InvalidRecord`), `TournamentTest` enum `ArgumentError`.
- **Lifecycle:** `TournamentCancelService`, `TournamentRestoreService` tests + integration tests.
- **Time:** `TournamentTime` tests incl. DST/cross-midnight/all-day exclusive end.
- **Query correctness:** `tournament_query_test.rb` (combined filters, `organisation_ids[]`, pagination).
- **DB integrity:** `organisation_test.rb` delete guard; division code-lock/final-active tests.
- **No Playwright harness exists**; request-level integration tests are the E2E-equivalent layer (decision recorded in phase_9.md).

## Reproduction

```bash
# frontend
cd beachvolleyballhub && npx vitest run && npx tsc -b && npx eslint . && npm run build
# backend
cd beachvolleyballhub_api && RAILS_ENV=test bundle exec rails test \
  test/models/tournament_test.rb test/models/organisation_test.rb \
  test/services/tournament_query_test.rb test/controllers/api/v1/tournaments_integration_test.rb
```
