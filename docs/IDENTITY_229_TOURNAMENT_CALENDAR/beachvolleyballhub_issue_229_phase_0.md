## 2. Phase 0 — Audit current HEAD and write an implementation delta

**Objective:** Identify existing implementations and recent changes before generating migrations or components.

1. Pull `main` for both repos; record `git rev-parse HEAD`, branch, clean status and latest migrations.
2. Inspect backend `db/schema.rb`, `config/routes.rb`, `app/models`, `app/controllers/api/v1`, policies/authorization, pagination concern, tests, and current identity and organisation membership relationships.
3. Inspect frontend `src/App.tsx`, `src/api.ts`, `src/components/Sidebar.tsx`, `src/pages/TrainingCalendar.tsx`, `src/utils/calendar.ts`, route guards, types, existing tests and styling.
4. Search for `Tournament`, `TournamentDivision`, `tournaments`, `watch_links`, `participation`, and calendar components. Determine what issue #229 has already implemented.
5. Compare HEAD with issue #229's documented commit hashes; identify changed or superseded assumptions.
6. Write `docs/tournament_calendar_v2/audit.md` with verified paths, models, endpoints, migrations, gaps, conflicts, and an implementation/no-op matrix. Do not replace or rename existing working features.
7. Establish baseline `bin/rails test`, frontend test/build/lint commands and existing failures.

**AI prompt — current-code audit**

You are working in two local repositories:
- beachvolleyballhub_api (Rails/PostgreSQL)
- beachvolleyballhub_frontend (React/TypeScript/Vite)

Read https://github.com/romalopes/beachvolleyballhub_api/issues/229 and the entire relevant local code, prioritizing current HEAD over the issue's 7 Oct assumptions. Do not implement yet. Record HEAD SHAs. Inspect routes, models, schema, controllers, auth/impersonation, pagination, calendar utilities, UI navigation, API client, and tests. Identify any tournament code already implemented, including partial work. Create docs/tournament_calendar_v2/audit.md with a file-by-file change matrix, architectural discrepancies, migration safety risks, and executable baseline test commands. Explicitly distinguish VERIFIED facts from proposals. Do not invent file paths or existing classes.

**Gate:** Audit approved, no conflicting existing tournament implementation, baseline test status documented.