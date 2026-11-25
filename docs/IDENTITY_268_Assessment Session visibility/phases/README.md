# AssessmentSession Visibility — Phase Documentation Index

**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md`

One implementation document per phase. Each records: the exact work, actual repo touchpoints, tests, acceptance criteria, and deviations from the parent plan.

## Phase Status Tracker

| Phase | Title | Status | Doc | Verified |
|-------|-------|--------|-----|----------|
| 00 | Repository & working-tree verification | ✅ Done | [phase-00-repository-verification.md](./phase-00-repository-verification.md) | Both repos clean on `main` |
| 01 | Codebase inspection & architecture report | ✅ Done | [phase-01-architecture-report.md](./phase-01-architecture-report.md) | Findings checked against source |
| 02 | Authorization & data contract | 🟡 Draft — awaiting owner approval | [phase-02-authorization-and-data-contract.md](./phase-02-authorization-and-data-contract.md) | Q1–Q7 open |
| 03 | Database migration & model | ✅ Done | [phase-03-database-migration-and-model.md](./phase-03-database-migration-and-model.md) | Migration + model + tests pass |
| 04 | Centralized authorization policy | ✅ Done | [phase-04-centralized-authorization-policy.md](./phase-04-centralized-authorization-policy.md) | 28 policy tests + controller wiring pass |
| 05 | API retrieval, visibility updates & sharing links | ✅ Done | [phase-05-api-retrieval-visibility-updates-sharing.md](./phase-05-api-retrieval-visibility-updates-sharing.md) | 18 controller tests pass |
| 06 | Protect nested resources & media | ✅ Done | [phase-06-protect-nested-resources-media.md](./phase-06-protect-nested-resources-media.md) | 10 new tests added, 83 total pass |
| 07 | Frontend visibility settings & indicators | ✅ Done | [phase-07-frontend-visibility-settings-indicators.md](./phase-07-frontend-visibility-settings-indicators.md) | Build passes, components integrated |
| 08 | Unlisted sharing experience | ✅ Done | [phase-08-unlisted-sharing-experience.md](./phase-08-unlisted-sharing-experience.md) | Build passes, public share page with login continuation |
| 09 | Routing, login continuation & listing behavior | ✅ Done | [phase-09-routing-login-continuation-listing.md](./phase-09-routing-login-continuation-listing.md) | Build passes, login continuation via returnTo, policy scope filters listings |
| 10 | Audit logging | ✅ Done | [phase-10-audit-logging.md](./phase-10-audit-logging.md) | Build passes, audit logs for create/update/visibility-change/regenerate-share-link/destroy |
| 11 | Security review & integration testing | ✅ Done | [phase-11-security-review-integration.md](./phase-11-security-review-integration.md) | All checks pass, 83 session tests, 2179 total tests |

## Global conventions (enforced in every phase)

| Area | Convention | Reference |
|------|------------|-----------|
| Test framework (API) | Minitest + fixtures — `bin/rails test` | `test/test_helper.rb` |
| Test framework (frontend) | Vitest + React Testing Library — `npm run test` | `beachvolleyballhub/package.json` |
| API auth | Bearer token (`bvb_api_token`) | `beachvolleyballhub/src/api.ts` |
| Roles | `guest, player, coach, curator, admin`; `content_manager? = coach‖curator‖admin` | `app/models/user.rb` |
| Authorization | Pundit — extend `AssessmentSessionPolicy`, never duplicate checks in controllers/React | `app/policies/` |
| Serialization | Inline `serialize(record, detail:)` in controllers | `app/controllers/api/v1/assessment_sessions_controller.rb` |
| Visibility storage | D1: string column `visibility`, `VISIBILITIES` constant, DB default `internal` + CHECK constraint (NOT an integer enum) | Phase 1 deviations |
| Share tokens | D2: SHA-256 digest stored, raw token returned once, never logged/persisted/analytics | Parent plan §2.2 |
| Secrecy | Raw tokens absent from logs, errors, audit events, analytics | Parent plan §2.2, §10 |