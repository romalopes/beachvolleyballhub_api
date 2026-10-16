# Tournament Calendar V2 — Deployment & Release Runbook

Issue #229 · Prepared 2026-10-16 · Status: **release-ready, not yet deployed** — this runbook documents verified commands and the release decision checklist. No production deployment or configuration change was made as part of this phase.

Companion docs: [README](./README.md) · [api_contract](./api_contract.md) · [data_model](./data_model.md) · [admin_guide](./admin_guide.md) · [user_guide](./user_guide.md) · [test_matrix](./test_matrix.md) · [audit](./audit.md)

## 1. Release topology (as inspected in the workspace)

| Component | Provider | Evidence |
| --- | --- | --- |
| Rails API | Render (`beachvolleyballhub_api`, Ruby 3.4.2, Rails 8.1, PostgreSQL) | `Dockerfile`, no `render.yaml` in-repo — service is configured in the Render dashboard; env vars via Render environment groups |
| PostgreSQL | Render-managed Postgres (backups mirrored to Cloudflare R2 by GitHub Actions) | `.github/workflows/database_backup.yml`, `database_restore_test.yml`, `database_backup_freshness.yml` |
| Frontend SPA | Cloudflare Workers (`beachvolleyballhub.romalopes.workers.dev`, previews `*-beachvolleyballhub.romalopes.workers.dev`) | `config/initializers/cors.rb` allow-list |
| Frontend runtime config | `VITE_API_BASE_URL` (absolute `https://…/api/v1` in deployed builds; empty default `/api/v1` for the dev proxy) | `src/api.ts:6`, `vite.config.ts` proxy |
| Monitoring | Sentry (DSN present in both repos' env) | `VITE_SENTRY_DSN`, `SENTRY_DSN` in dotenv |

A legacy `vercel.json` (SPA rewrite) remains in the frontend repo but the configured CORS surfaces are Cloudflare Workers domains; treat Cloudflare as canonical.

## 2. Database migration — additive and sequenced

Tournament V2 is one migration, applied **before** the app code that requires it:

```
20261009000003  Create tournament tables
```

(verified: `bin/rails db:migrate:status` shows this entry `up` in a prepared database)

- Creates `tournaments`, `tournament_divisions`, `tournament_participations`, `tournament_watch_links` (see [data_model](./data_model.md)).
- Fully additive: new tables + FKs referencing existing `organisations` (`on_delete: :restrict`) and `accounts`; no existing column is altered or dropped, so a rollback of app code leaves the database valid and harmless.
- **Sequencing rule:** deploy the migration first, then the API image, then the frontend. Because the migration only adds tables, the reverse order is also safe (old API ignores new tables), which makes rollback-by-revert low risk.

Release-day commands (API service shell / Render one-off job):

```bash
bin/rails db:migrate:status   # confirm 20261009000003 is the head and not yet applied
bin/rails db:migrate          # apply
bin/rails db:migrate:status   # confirm "up"
```

## 3. Backup before deploying

Mandatory pre-deploy backup per [DATABASE_BACKUP_AND_RESTORE](../DATABASE_BACKUP_AND_RESTORE.md):

1. Run **Database Backup** (GitHub Actions → [database_backup.yml](https://github.com/romalopes/beachvolleyballproject_api/actions/workflows/database_backup.yml)) against the production provider.
2. Verify in R2: dump + checksum + metadata sidecars present, nonzero sizes.
3. Optionally run **Database Restore Test** ([database_restore_test.yml](https://github.com/romalopes/beachvolleyballproject_api/actions/workflows/database_restore_test.yml)) if the last verified restore is older than 7 days.
4. Record the backup run URL in the release checklist below. **Do not proceed without a restorable backup.**

## 4. Deploy sequence

1. **API to Render:** merge to `main` (CI must be green — see §8). Render builds from `Dockerfile`. Confirm the deploy finishes and `bin/rails db:migrate:status` inside the new image reports the tournament migration `up` (or run the one-off migrate job before switching traffic).
2. **Feature exposure:** the project has **no backend feature-flag system** for tournaments (checked: no Flipper/feature-flag gem; visibility is enforced by `publication_state` — default `draft` — and by `scope`/authorisation). Exposure control is therefore frontend-side: the "Tournament Management" admin link and `/tournaments` entry render regardless, but the public API only lists `active`/published tournaments by default, and `draft` rows are only visible to organisation admins via `publication_state` filtering. Public exposure is thus gated by admins publishing — treat "first admin publishes a tournament" as the go-live event.
3. **Frontend to Cloudflare:** deploy the Workers build with `VITE_API_BASE_URL` pointing at the Render API's `/api/v1`. Verify no `VITE_*` secret is set (they ship in browser JS).
4. **CORS check:** deployed frontend origin must be in `config/initializers/cors.rb`'s allow-list — production needs `CORS_ORIGINS` (or the `FRONTEND_URL` fallback) to include the Workers domain. Workers preview domains `*-beachvolleyballhub.romalopes.workers.dev` are already matched by regex.

## 5. Post-deploy smoke tests (execute in order, note results in the release record)

| # | Flow | How |
| --- | --- | --- |
| 1 | API health | `GET /api/v1/health` (or configured health endpoint) returns 200 from Render |
| 2 | Migration status | one-off `bin/rails db:migrate:status` → `up 20261009000003` |
| 3 | Guest directory | open `/tournaments` in the deployed SPA as signed-out user; empty directory renders without console errors |
| 4 | Admin create | admin creates a tournament via `/admin/tournaments`, adds a division + watch link, publishes |
| 5 | Participation | a signed-in member self-links via tournament detail and sees it in `/my-tournaments` |
| 6 | Timezone | create a tournament in a non-UTC timezone; verify the calendar groups it on the correct local day |
| 7 | Regression: training calendar | open `/calendar`, switch months, confirm sessions still render |
| 8 | CORS/network | devtools: no CORS or mixed-content errors; requests hit the Render domain |

## 6. Monitoring

- **Errors:** Sentry (API `SENTRY_DSN`, frontend `VITE_SENTRY_DSN`). Watch the first 24 h for new issues tagged with tournament controllers/services.
- **Logs:** Render log drain — grep for `TournamentsController`, `Tournament*Service`, `ActiveModel::UnknownAttributeError`, `ArgumentError`.
- **Memory/render checks:** Render metrics dashboard (response time p95, memory); tournament queries are paginated (`per_page` default 25, capped by `TournamentQuery`).
- **Backup freshness:** scheduled [database_backup_freshness.yml](https://github.com/romalopes/beachvolleyballproject_api/actions/workflows/database_backup_freshness.yml) must stay green post-release.

## 7. Rollback

Ordered from least to most invasive; **never** roll back the destructive-free schema migration while real user data exists — the migration is additive, so leaving it applied after an app revert is correct.

1. **Hide the feature (frontend only):** redeploy the SPA with the tournaments routes/navigation removed, or revert the frontend commit. Public users lose the surface; API stays.
2. **Revert the API image:** redeploy the previous Render image. Safe because the migration is additive (old code ignores the new tables).
3. **Data recovery (last resort):** restore the pre-release backup per [DATABASE_BACKUP_AND_RESTORE](../DATABASE_BACKUP_AND_RESTORE.md) into a disposable database first, then cut over. This discards all data written after the backup — requires explicit approval.
4. The tournament tables' own data can be dropped selectively (`tournament_watch_links` → `tournament_participations` → `tournament_divisions` → `tournaments`, respecting FK order) without touching any other feature's tables.

## 8. CI (verified in-repo)

`.github/workflows/ci.yml` on the API repo runs brakeman, bundler-audit, importmap audit, rubocop, and the Rails test suite on PRs and `main` pushes. The frontend repo has no CI workflow — its gates are local (`npx vitest run`, `npx tsc -b`, `npx eslint .`, `npm run build`), all verified green on 2026-10-16 (see [test_matrix](./test_matrix.md)).

## 9. Operational ownership

| Concern | Owner | Where |
| --- | --- | --- |
| Render service + env vars | Romalopes (repo admin) | Render dashboard |
| Migrations | Whoever deploys; verify with `db:migrate:status` | §2 |
| Backups/restore | Repo admin + GitHub Actions secrets owner | `DATABASE_BACKUP_AND_RESTORE.md` |
| DNS/Workers | Cloudflare account owner | CORS allow-list sync |
| Content go-live | Organisation admins (publish tournaments) | `/admin/tournaments` |

## 10. Release decision checklist

- [ ] CI green on `main` for both repos (API workflow; frontend gates run locally)
- [ ] Tournament migration verified `up` in staging-equivalent (or verified additive review)
- [ ] Pre-deploy backup run, verified in R2, run URL recorded: ____________
- [ ] `CORS_ORIGINS`/`FRONTEND_URL` includes the deployed frontend origin
- [ ] Deploy API → smoke tests 1–2 pass
- [ ] Deploy frontend with correct `VITE_API_BASE_URL` → smoke tests 3–8 pass
- [ ] Sentry free of new tournament-tagged issues after 24 h
- [ ] Rollback owner and decision criteria (§7 step 1 trigger) named: ____________
- [ ] Production changes approved by: ____________
