# Tournament Calendar V2 — Documentation Set

Issue #229 · Implemented October 2026 · Phase docs: [`../IDENTITY_229_TOURNAMENT_CALENDAR/`](../IDENTITY_229_TOURNAMENT_CALENDAR/beachvolleyballhub_issue_229_implementation_plan.md)

Tournament Calendar V2 adds multi-organisation tournaments with divisions, watch links, participation, publication lifecycle (`draft → active → cancelled/archived`, restorable) and timezone-aware all-day scheduling to the Rails API + React SPA.

## Documents

| Doc | Purpose |
| --- | --- |
| [deployment.md](./deployment.md) | Release runbook: topology, migration sequencing, backup, smoke tests, monitoring, rollback, release decision checklist |
| [api_contract.md](./api_contract.md) | Tournament endpoints, params, payloads and status codes |
| [data_model.md](./data_model.md) | Tables, enums, locks and integrity rules |
| [admin_guide.md](./admin_guide.md) | Admin workflows: create, divisions, watch links, lifecycle |
| [user_guide.md](./user_guide.md) | Member flows: directory, filters, detail, participation, My Tournaments |
| [test_matrix.md](./test_matrix.md) | Verified test evidence per suite and remaining known failures |
| [audit.md](./audit.md) | Security review: authentication, authorization, input validation findings |

## Quick facts

- **Migration:** `20261009000003_create_tournament_tables.rb` — purely additive (verified via `bin/rails db:migrate:status`).
- **API surface:** `/api/v1/tournaments` + nested `divisions` / `watch_links` / lifecycle / `participate` (verified via `bin/rails routes`); filterable by search, scope, organisations, division scheme/levels, location, temporal status, publication state.
- **Authorisation:** real-admin + organisation-membership based (`TournamentManagementAuthorization`); public read is gated by `publication_state`.
- **Frontend:** public directory + calendar views, `My Tournaments`, admin form with divisions/watch links/lifecycle under `/admin/tournaments`.
- **Tests:** frontend 895/895 vitest, `tsc -b`, `eslint .`, `vite build` all green; backend tournament model/service/controller suites green (see [test_matrix](./test_matrix.md)).
