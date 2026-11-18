# Phase 0 — Repository audit and implementation design

**Parent plan:** [beachvolleyballhub_contact_messages_implementation_plan.md](beachvolleyballhub_contact_messages_implementation_plan.md)
**Plan section:** §1, §3, phase table row 0
**Status:** Complete (audit only — no code was changed by this phase).

This document records what the two repositories actually contain. Every later
phase refers back to it instead of re-deriving conventions.

## 1. API environment (`beachvolleyballhub_api`)

| Item | Finding |
|---|---|
| Rails / Ruby | Rails 8.1.3 (`config.load_defaults 8.1`), Ruby 3.4.2 |
| Database | PostgreSQL (`pg`); production uses one Neon database for `primary`, `cache`, `queue` and `cable` (`config/database.yml`) |
| Authorization | Pundit; `ApplicationController#rescue_from Pundit::NotAuthorizedError` maps denials to 401 (anonymous), 404 (read-by-id), 403 (otherwise) |
| Admin gate | `AdminAreaPolicy#access?` → `real_admin?` (admins only, survives impersonation) via `authorize_admin!` |
| Roles | **Global**: `Role` + `UserRole` (`guest`, `player`, `coach`, `curator`, `admin`). `User#admin?/curator?/coach?/player?` |
| Organisation roles | Separate concept: `OrganisationMembership#role`. They can never satisfy `user.curator?` |
| Notifications | `Notification` (unique `(account_id, event_key)`), `Notifications::Publisher.publish(...)`, `Notifications::WorkflowEvents`; recipients are **Accounts**; `NotificationPreference#event_enabled?` may mute a type |
| Mail | `ApplicationMailer` sets `default from: MailSender.from, reply_to: MailSender.reply_to` |
| `MAIL_REPLY_TO` | A **Reply-To header** (`lib/mail_sender.rb`), *not* a recipient list. Preserved unchanged |
| Transports | Brevo / Resend / SMTP / file via `MailTransport.resolve` (`lib/mail_transport.rb`) |
| Jobs | Active Job + **Solid Queue** in production (`config/environments/production.rb`, `config/queue.yml`), entry point `bin/jobs`; `config/deploy.yml` documents a separate job role |
| Worker on Render | **Already deployed**: the active blueprint `beachvolleyballhub_api/render.yaml` declares `bvb-api-worker` (`dockerCommand: ./bin/jobs`). The legacy combined blueprint at the repository root has no worker and is not the one used for the API |
| Rack::Attack | Gem installed, initializer at `config/initializers/rack_attack.rb` (100/min general, billing throttle, JSON 429 responder); mounted by the gem's railtie |
| Cloudflare Turnstile | **Absent** — no verifier, no keys, no frontend widget |
| API conventions | `/api/v1/...`; `{ data: [...], meta: { page, per_page, total, total_pages } }`; `{ errors: [...] }` 422; `{ error: "..." }`; `X-Idempotency-Key` support; `TestAccess` gate |
| Tests | Minitest + fixtures; `sign_in_as`, `api_session_for`; `test/lib`, `test/policies`, `test/mailers`, `test/jobs` already exist |

## 2. Frontend environment (`beachvolleyballhub`)

| Item | Finding |
|---|---|
| Stack | React 19, react-router 7 (`src/App.tsx`), Vite 8, vitest + Testing Library, ESLint flat config |
| Public navigation | Top-level links: Home, Tournaments, Training Sessions; groups: Development, Training Management, Community (staff), Assessments (staff), User (signed in) |
| About page | **Does not exist** → the plan's "before About" rule cannot apply (decision in Phase 3) |
| Route guards | `AdminRoute` (admin), `ManagerRoute` (coach/curator/admin), `LocationOversightRoute` (curator/admin), `AuthenticatedRoute` |
| Settings | `SettingsDashboard` and every `/settings/*` route are admin-only (`AdminRoute`) |
| API client | `src/api.ts`: `fetchAPI`, `postJSON`, `ApiValidationError`, `PaginatedResponse<T>` |
| Reusable UI | `SettingsLayout`, `Pagination`, `EmptyState`, `ErrorState`, `LoadingState`, `AdminTable`; public form styling from `Signup.tsx` (`page auth-page` → `auth-card`) |
| Env vars | `VITE_API_BASE_URL`, `VITE_GOOGLE_MAPS_EMBED_API_KEY`, feature flags; typed in `src/vite-env.d.ts` |

## 3. Deployment findings

- **Two** Render blueprints exist: `beachvolleyballhub_api/render.yaml` (active —
  Docker `bvb-api` web service with `bin/render-predeploy.sh`, Neon database and a
  **`bvb-api-worker`** Solid Queue worker) and the repository-root `render.yaml`
  (legacy combined API/renderer/static-site blueprint, no worker). This feature
  only adds environment variables to the active API blueprint.
- Frontend production origin: `https://beachvolleyballhub.com` (CORS already
  allow-lists it, plus Cloudflare Workers previews).
- `config/environments/production.rb` sets
  `config.action_dispatch.trusted_proxies` to the default list **plus Cloudflare
  CIDR ranges**, so `req.ip` is trustworthy behind Render/Cloudflare.
- Sentry is configured (`config/initializers/sentry.rb`); operational logging
  uses `Rails.logger`.

## 4. Decisions taken from the audit

| Decision | Reason |
|---|---|
| Inbox access = platform `admin` **or** `curator` | Both are global roles; the plan's matrix maps directly onto them without a new role. Organisation roles live elsewhere and cannot leak in |
| No new role, no new notification system, no new mail provider | Plan §3 "non-negotiable compatibility" |
| Recipients come from a new `CONTACT_NOTIFICATION_EMAILS` | `MAIL_REPLY_TO` is a header and must keep its meaning |
| Turnstile must be built from scratch | Nothing existed to reuse |
| Contact placed as a top-level public nav link | No About page exists (Phase 3 documents this) |

## 5. Risks identified (and how they are handled)

1. **Worker configuration drift** → the worker already exists, but it needs the
   same `CONTACT_NOTIFICATION_EMAILS` and mail settings as the web service;
   Phase 2 documents that requirement.
2. **`show?` denials render 404** → tests assert 404 for unauthorised
   read-by-id (the app-wide contract) instead of 403.
3. **Turnstile single-use tokens** → the frontend resets the widget after every
   failed or successful submit.
4. **Shared NAT rate limits** → the per-IP limits are environment-configurable.
5. **Duplicate delivery on retry** → `emailed_at` / `notified_at` outbox columns
   plus the idempotent notification `event_key`.

## 6. Exit criteria

| Criterion | Result |
|---|---|
| No code changes in this phase | ✅ audit only |
| Clear architecture map with file paths | ✅ §1–§3 |
| Platform Admin/Curator semantics confirmed | ✅ global `Role`/`UserRole` |
| `MAIL_REPLY_TO` semantics confirmed | ✅ Reply-To header, preserved |
| Worker deployed and processing jobs | ✅ `bvb-api-worker` in the active blueprint (env vars to extend) |
| Rack::Attack active | ✅ initializer present and mounted by the railtie |
| No duplicate notification/mail/role systems proposed | ✅ |
