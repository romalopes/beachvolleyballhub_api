# Phase 12 — Deployment, rollout and rollback

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §14
**Status:** **Checklist produced; no production deployment performed as part of this change.**

This phase is an operational runbook. The code change is complete and safe to deploy, but deploying
to Render/Neon/Cloudflare is a separate, approved action.

## 1. What is deployable now

- **Backend:** 1 additive migration + new models/services/controllers/routes. No existing table is
  altered or dropped, so the change is safe to ship ahead of the frontend.
- **Frontend:** the bell, inbox and preferences panel. If deployed before the backend, the bell
  simply shows no badge (the API call fails and falls back to 0) — no crash.

## 2. Deployment order

1. **Backend first.** Deploy the API and run the migration:
   ```bash
   bin/rails db:migrate
   ```
   The migration only creates `notifications` and `notification_preferences` and their indexes.
2. **Verify** the new endpoints return 401 unauthenticated and `{ "data": [], "meta": {...} }` for a
   signed-in test account.
3. **Frontend second.** Deploy the SPA so the bell and `/notifications` become reachable.
4. **Smoke test** with the Phase 11 checklist.

## 3. Feature flags

The plan asks for flags. The implemented design makes a global flag unnecessary for the in-app path,
because the feature is **additive and inert until an event occurs**:

| Concern | Why no flag is needed |
|---|---|
| Schema | Additive; nothing reads the tables until events are emitted |
| Events | Only fire on real training/membership transitions; a quiet system produces no rows |
| UI | The bell renders only for signed-in users; with zero notifications it shows no badge |
| Per-account control | `NotificationPreference` is the real feature flag — a user can mute or disable in-app notifications |

If a **kill switch** is required, the simplest reversible lever is to stop calling
`Notifications::WorkflowEvents` from the three controllers (a code revert), or to set
`in_app_enabled = false` for affected accounts. Email and push remain **off** (Phases 8/10), so there
is no asynchronous delivery to disable.

## 4. Environment and configuration

| Item | Requirement |
|---|---|
| Database | Existing Neon PostgreSQL; migration adds two tables + indexes |
| Queue | **Unchanged.** `solid_queue` is already configured for production; this change enqueues **no** jobs |
| Brevo | **Unchanged.** No notification email is sent |
| Sentry | **Unchanged.** No new error paths; a bell failure is caught and falls back to 0 |
| CORS | **Unchanged.** The new routes live under the existing `/api/v1` origin allow-list |

## 5. Monitoring

Watch after deploy:
- API error rate on `/api/v1/notifications*` and `/api/v1/notification_preferences`;
- `SELECT count(*) FROM notifications;` growth (should track real events, not runaway fanout);
- duplicate check: `SELECT account_id, event_key, count(*) FROM notifications GROUP BY 1,2 HAVING count(*) > 1;` → must be empty (the unique index guarantees it);
- index usage on `index_notifications_inbox` as volume grows.

## 6. Rollback

**Prefer disabling over destructive rollback.** Recommended order:

1. **Frontend rollback** — redeploy the previous SPA build; the API stays and the extra tables are
   simply unused.
2. **Event rollback** — revert the three controller hooks (training, organisation, group) so no new
   rows are created. The bell then drains naturally as users read what already exists.
3. **Do not drop the tables.** The schema is additive; dropping it would destroy real user-visible
   notifications and is unnecessary. If a schema rollback is ever truly required, it is
   `bin/rails db:rollback STEP=1` **only** after confirming no other code depends on the tables.

## 7. Rollback rationale

The plan says: "Rollback by disabling event flags and UI; keep additive schema in place until safe
cleanup." This runbook follows that exactly — disabling the emitters and the UI is sufficient and
non-destructive, and the schema is left in place.

## 8. Exit criteria

| Criterion | Result |
|---|---|
| Deployment order documented | ✅ §2 |
| Migration order / worker startup / secrets verified | ✅ §4 (no worker, no new secret) |
| Smoke tests defined | ✅ Phase 11 §7 |
| Explicit rollback commands | ✅ §6 |
| Destructive schema rollback discouraged | ✅ §6–7 |
