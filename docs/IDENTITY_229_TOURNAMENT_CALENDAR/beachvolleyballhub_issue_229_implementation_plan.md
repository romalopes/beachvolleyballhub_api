# BeachVolleyballHub — Issue #229: Tournament Calendar V2

**Prepared:** 15 October 2026
**Issue:** https://github.com/romalopes/beachvolleyballhub_api/issues/229
**Backend:** https://github.com/romalopes/beachvolleyballhub_api
**Frontend:** https://github.com/romalopes/beachvolleyballhub_frontend

> **Verification status:** The public issue and repository landing pages were accessed on 15 October 2026. A full checkout of the latest repositories was not possible in this environment. The issue itself records an earlier code audit (7 October 2026), at backend commit `ce5aa1ea2711ad89f9a8652ae923b9a49c2c8f38` and frontend commit `054fba328750f1f447f4846cfa0121848e19fae7`. Treat its architectural findings as a baseline, **not** proof of the current code. Phase 0 must verify actual HEAD before modifying anything.

## 1. Goal and architectural decisions

Implement a searchable tournament directory, month/list calendar, detailed tournament pages, multiple competition divisions, self-declared Account participation, My Tournaments, and ordered streaming/watch links. Reuse existing Rails 8 API, PostgreSQL, Organisation, User/Account, authentication, pagination, and React 19/TypeScript/Vite calendar infrastructure.

**Key decisions:**

- Use `Organisation`, not `Organization`; never duplicate the organisation hierarchy.
- `Tournament.scope` describes club/state/national/international/other; `TournamentDivision` describes competitive strength.
- One tournament has many divisions, using either letter levels (B, BB, BBB, A, AA, AAA, AAAA) or numbered divisions (1 strongest, then 2, 3...). Do not equate schemes.
- `TournamentParticipation` belongs to `Account`, not a legacy `Person` or individual PlayerProfile; role selection does not grant application permissions.
- Guest tournament discovery is read-only and subject to the existing private test-access gate. Organisation rosters stay protected.
- Calendar interval semantics are half-open `[starts_at, ends_at)`, with explicit IANA timezones and correct DST/all-day behavior.
- Reuse existing `/calendar` training page unchanged. Tournament discovery gets its own route and view.
- Administration defaults to existing `admin` authority, not the broader coach/curator content-manager role.
- Defer official registration, teams, payments, brackets, scoring, ranking, and eligibility enforcement.

## Phase Details

### Phase 0 — Audit current HEAD and write an implementation delta
**Objective:** Identify existing implementations and recent changes before generating migrations or components.
[Read full phase details](./beachvolleyballhub_issue_229_phase_0.md)

### Phase 1 — Database schema and model invariants
**Objective:** Implement only Phase 1 from docs/tournament_calendar_v2/audit.md and the issue #229 plan. Follow actual Rails migration and model conventions. Create Tournament, TournamentDivision, TournamentParticipation, TournamentParticipationDivision, TournamentWatchLink and associations with Organisation and Account. Use database CHECK/unique/FK constraints, including composite constraints ensuring a selected division belongs to the participation's tournament. Use transactional services for cross-row invariants. Do not add Person, Organization, a second auth system, or a serializer framework. Update organisation deletion checks/counts so the UI cannot offer forbidden deletion. Add focused Minitest coverage for constraints, associations, races, and deletion. Do not edit frontend. Show migration rollback implications and test output.
**Status:** ✅ COMPLETED
[Read full phase details](./beachvolleyballhub_issue_229_phase_1.md)

### Phase 2 — Tournament domain services, lifecycle, timezones
**Objective:** Build domain services for tournament lifecycle (create, update, archive, publish) with transactional guarantees. Implement timezone-aware calendar interval logic, all-day event handling, and DST-safe computations. Create value objects for recurrence patterns (if any) and duration. Add service object tests covering edge cases (leap years, month-end, timezone transitions). Do not modify frontend. Show service test output.
**Status:** 🔄 IN PROGRESS
[Read full phase details](./beachvolleyballhub_issue_229_phase_2.md)

### Phase 3 — Search, calendar query and pagination
**Objective:** Implement search (by name, scope, division, location, date) and calendar queries (month, week, day) with pagination. Reuse existing pagination concern. Ensure calendar query includes overlapping events (not just starts_at in range). Add backend tests for search and query logic. Do not modify frontend. Show query test output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_3.md)

### Phase 4 — Rails API and authorization
**Objective:** Create API endpoints for tournaments, divisions, participations, and watch links. Apply existing authentication and authorization (admin authority). Use strong parameters, pagination, and proper error handling. Add request specs for endpoints, including authentication and authorization tests. Do not modify frontend. Show API test output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_4.md)

### Phase 5 — Frontend types, API client and reusable UI
**Objective:** Generate TypeScript types from API (or define manually). Create API client functions for tournament resources. Build reusable UI components (tournament card, division badge, participation button). Ensure types cover all backend fields and validation. Add unit tests for types and API client. Do not modify backend. Show frontend type and unit test output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_5.md)

### Phase 6 — Tournament directory and calendar
**Objective:** Build tournament directory page (search, filters, list) and month/list calendar view. Use existing calendar infrastructure. Implement routing and navigation. Connect to backend API. Add integration tests for directory and calendar. Do not modify backend. Show frontend build and test output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_6.md)

### Phase 7 — Tournament detail, My Tournaments, self-link
**Objective:** Build tournament detail page (show tournament, divisions, watch links). Implement My Tournaments page (list of participations). Allow authenticated Accounts to self-link to tournaments (select role/divisions) and unlink. Add integration tests for detail, My Tournaments, and participation flow. Do not modify backend. Show frontend build and test output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_7.md)

### Phase 8 — Admin forms and organisation integration
**Objective:** Build admin forms for creating/editing tournaments and divisions. Integrate with Organisation scope (only admins of an organisation can manage its tournaments). Add organisation deletion guards (tournaments must be archived or deleted before organisation deletion). Do not modify backend. Show frontend build and test output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_8.md)

### Phase 9 — Security, quality and integration testing
**Objective:** Perform security review (authentication, authorization, input validation). Run backend and frontend test suites. Fix any flaky tests. Add end-to-end tests for critical user flows (guest search, participant self-link, admin management). Ensure no regressions in existing `/calendar` training feature. Show security audit report and test suite output.
[Read full phase details](./beachvolleyballhub_issue_229_phase_9.md)

### Phase 10 — Rollout, operations and documentation
**Objective:** Prepare release checklist for Tournament Calendar V2 across Render Rails API, PostgreSQL and Cloudflare frontend. Inspect actual deployment configuration, environment variables, CI workflows and CORS. Document additive migration sequencing, backup/restore, smoke tests, monitoring, feature exposure, rollback and operational ownership. Do not deploy or change production without explicit approval. Produce docs/tournament_calendar_v2/deployment.md and README.md with verified commands, links and a release decision checklist.
[Read full phase details](./beachvolleyballhub_issue_229_phase_10.md)
## 13. Suggested pull-request sequence

| PR  | Repository     | Scope                                      | Dependency |
| --- | -------------- | ------------------------------------------ | ---------- |
| 0   | Both           | HEAD audit and design documentation        | none       |
| 1   | API            | schema, associations, constraints, tests   | 0          |
| 2   | API            | mutation/participation services, lifecycle | 1          |
| 3   | API            | query/filter/calendar logic                | 1          |
| 4   | API            | endpoints, auth, request tests             | 2–3        |
| 5   | Frontend       | API types, helpers, shared components      | 4 contract |
| 6   | Frontend       | tournament calendar and directory          | 5          |
| 7   | Frontend       | details, participation, My Tournaments     | 5–6        |
| 8   | Frontend + API | admin UI and organiser integration         | 4–7        |
| 9   | Both           | security, E2E, docs, deployment            | all        |

## 14. Definition of done

- [ ] Verified HEAD audit documents actual implementation delta.
- [ ] Database constraints and concurrent writes are safe.
- [ ] Tournaments support multiple ordered letter or numbered divisions.
- [ ] Calendar includes all overlapping events, not just events starting in range.
- [ ] Timezones, DST and all-day dates are correct.
- [ ] Guests can discover non-archived tournaments without exposing organisation/member data.
- [ ] Admin alone manages tournaments and their child records.
- [ ] Authenticated Accounts can self-link, select role/divisions, update and unlink.
- [ ] My Tournaments works and does not claim official registration.
- [ ] Ordered watch links are safe and functional.
- [ ] Organisation deletion guards and existing access restrictions remain intact.
- [ ] Existing `/calendar` training feature remains unchanged.
- [ ] Backend and frontend automated tests, build, and smoke tests pass.
- [ ] Release and rollback documentation are complete.

## 15. Future iterations (out of scope)

Teams and partner matching; official registration/payment; division gender and age categories; brackets and draws; court schedules; scores/results/rankings; organiser delegation; organisation-restricted discovery; integrations/imports; push/email notifications; iCal export; automated player eligibility. Design extension points but do not implement prematurely.

## References

- [Issue #229 — Tournament Calendar V2](https://github.com/romalopes/beachvolleyballhub_api/issues/229)
- [Backend repository](https://github.com/romalopes/beachvolleyballhub_api)
- [Frontend repository](https://github.com/romalopes/beachvolleyballhub_frontend)
This is a evolution from [Issue 76](bvb-tournament-calendar-issue-76-plan.md)/([GiitHub 76](https://github.com/romalopes/beachvolleyballproject_api/issues/76)) | [GitHub issue 229](https://github.com/romalopes/beachvolleyballproject_api/issues/229)