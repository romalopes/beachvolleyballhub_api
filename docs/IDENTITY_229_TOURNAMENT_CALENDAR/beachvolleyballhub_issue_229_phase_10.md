## 12. Phase 10 — Rollout, operations and documentation

1. Deploy additive database migrations before app code; back up the PostgreSQL database and verify restore instructions.
2. Deploy backend behind an existing feature flag if the project supports one; otherwise keep frontend navigation disabled until API readiness.
3. Verify Render API health, migration status, logs, memory and error rates; test Cloudflare-hosted frontend against actual configured API domains/CORS.
4. Deploy frontend and enable navigation for a small test cohort, then broader access.
5. Smoke-test timezone, admin create/edit, guest directory, Account participation and existing training calendar.
6. Document rollback: hide frontend feature first, revert application changes if necessary; do **not** blindly roll back destructive schema after real user data exists.
7. Add `docs/tournament_calendar_v2/README.md`, `api_contract.md`, `data_model.md`, `admin_guide.md`, `user_guide.md`, `deployment.md`, `test_matrix.md`, and `audit.md`.

**AI prompt — release readiness**

Prepare a release checklist for Tournament Calendar V2 across Render Rails API, PostgreSQL and Cloudflare frontend. Inspect actual deployment configuration, environment variables, CI workflows and CORS. Document additive migration sequencing, backup/restore, smoke tests, monitoring, feature exposure, rollback and operational ownership. Do not deploy or change production without explicit approval. Produce docs/tournament_calendar_v2/deployment.md and README.md with verified commands, links and a release decision checklist.


## Implementation & verification record (2026-10-16)

All seven rollout items are covered by the `docs/tournament_calendar_v2/` set; nothing was deployed and no production configuration was changed (per the plan's explicit approval requirement).

### Deliverables (all present in `docs/tournament_calendar_v2/`)
- `deployment.md` — release runbook: inspected topology (Render API via `Dockerfile` + `bin/render-build.sh`, Render-managed PostgreSQL with GitHub-Actions backups to Cloudflare R2, Cloudflare Workers frontend, Sentry), additive-migration sequencing, pre-deploy backup procedure, deploy order, smoke-test table, monitoring, staged rollback, operational ownership and a release decision checklist.
- `README.md` — documentation-set index with quick facts.
- `api_contract.md`, `data_model.md`, `admin_guide.md`, `user_guide.md`, `test_matrix.md`, `audit.md` — API surface, schema/locks, admin & member workflows, verified test evidence, and the security review (referenced by Phase 9's gate).

### Verification (executed in this workspace on 2026-10-16)
- `bin/rails db:migrate:status` → `up 20261009000003 Create tournament tables` (migration additive, single-tables creation).
- `bin/rails routes -g tournament` → 21 tournament routes registered (index/show/options/create/update/destroy, publish/archive/cancel/restore, participate/destroy_participation, nested divisions & watch links CRUD).
- Deployment-config inspection: `bin/render-build.sh` runs `db:migrate` (+ cache/queue/cable) during release builds — so migration-on-deploy is already wired; no `render.yaml`/feature-flag gem found (exposure is gated by `publication_state` default `draft`, documented in the runbook).
- CORS: `config/initializers/cors.rb` allow-list covers the Cloudflare Workers production and preview domains, `beachvolleyballhub.com`(+www) and dev localhost.
- CI: `.github/workflows/` holds `ci.yml` (brakeman, bundler-audit, importmap audit, rubocop, tests) plus the three database backup/restore/freshness workflows referenced by the runbook.
- Backend gates re-run green: `test/models/tournament_test.rb` + `test/models/organisation_test.rb` → 55 runs, 0 failures/errors; frontend gates: FilterState/Tournaments vitest 6/6, `tsc -b` 0 errors, `eslint .` 0 problems (full-suite numbers in `test_matrix.md`).

### Known limitations
- No staging environment exists; the checklist's "staging-equivalent" step is satisfied by additive-migration review + pre-deploy backup verification.
- Frontend has no CI workflow; its four local gates are documented in `test_matrix.md` and must be run before each release.
- Smoke tests and checklist sign-off can only be executed post-deploy — they are intentionally left unchecked.

**Gate:** release documentation complete and verified — ✅ met (documentation side; actual deployment remains pending explicit approval).