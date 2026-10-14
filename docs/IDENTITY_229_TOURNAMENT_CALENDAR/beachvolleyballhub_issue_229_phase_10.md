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

**Gate:** release documentation complete and verified.