# Security Audit — Beach Volleyball Hub

Read-only audit of the database and Rails API exposure surface, followed by the
remediation actually shipped. This document records both what was verified and
what was changed; it does not describe planned work as done.

## Scope

- **Database**: Neon PostgreSQL, accessed by the Rails API (Render) only.
- **API**: `beachvolleyballhub_api` (Rails 8.1, JSON API + server-rendered HTML).
- **Frontend**: `beachvolleyballhub` (React SPA on Vercel / Cloudflare Workers).

## Database checklist

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Neon database isn't directly exposed to the browser | PASS | The SPA reads only `VITE_API_BASE_URL` (`src/api.ts`). No `DATABASE_URL`, no `VITE_DATABASE_*`. |
| 2 | `DATABASE_URL` exists only on Render/server-side | PASS | `config/database.yml` reads `ENV["DATABASE_URL"]`; `render.yaml` declares it `sync: false`. |
| 3 | No database credentials in GitHub | PASS | Workflows reference `${{ secrets.NEON_DATABASE_URL }}` / `SUPABASE_DATABASE_URL`. CI's `postgres://postgres:postgres@localhost:5432` is a throwaway localhost test DB. |
| 4 | No database credentials in Vercel frontend env vars | PASS | `vercel.json` holds only rewrites; frontend `.env*` hold only `VITE_API_BASE_URL`, `VITE_SENTRY_DSN`, `VITE_GOOGLE_MAPS_EMBED_API_KEY`. |
| 5 | No database credentials committed to Git | PASS | `/.env*` is gitignored in both repos; `config/*.key` is gitignored. |
| 6 | Database roles have only the permissions they need | MANUAL | All four Rails connections (primary/cache/queue/cable) share one `DATABASE_URL` role. Splitting roles is a Neon-console task, not a code change. |
| 7 | Backups are enabled | PASS | `.github/workflows/database_backup.yml` runs daily (02:00 UTC) to R2 with age encryption + SHA-256. |
| 8 | Restore has been tested | PASS | `.github/workflows/database_restore_test.yml` runs weekly into a disposable DB with a fail-closed production guard. |
| 9 | SSL/TLS is used for database connections | FIXED | `config/database.yml` production now sets `sslmode: require`. |

### Credential hygiene note

`beachvolleyballhub_api/.env.development` and `.env.development.local` contain
plaintext secrets (Neon passwords, SMTP password, provider API keys, the age
backup identity). Both are gitignored and therefore not in Git, but any copy of
the developer machine or that directory exposes them. Prefer Rails encrypted
credentials (`config/credentials.yml.enc`) or an OS keychain for values that are
not needed as raw environment variables at boot.

## Rails API checklist

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Authentication required where appropriate | PASS | `DrillsController` create requires `require_content_creator!`; update/destroy require ownership. |
| 2 | Authorization checked for every protected resource | PASS | `ContentAuthorization` concern applied across the API v1 controllers. |
| 3 | Users cannot modify another user's records | PASS | `authorize_content_owner!` compares the record's owner to `Current.user` (admin bypass only). |
| 4 | Admins/curators have explicit authorization | PASS | `User#content_manager?` = coach ∨ curator ∨ admin, used for management actions. |
| 5 | Object IDs cannot bypass authorization | PASS | Lookup by slug or id is followed by the same ownership check. |
| 6 | Private/unlisted drills aren't returned by public endpoints | FIXED | `Drill.published_and_shared` scope; `show` gated by `published_and_shared?`. |
| 7 | Draft drills aren't exposed through public queries | FIXED | New drills default to `draft`; only `published` + `shared` is public. |
| 8 | Mass assignment is controlled | PASS | Strong parameters with explicit permit lists; `created_by` set server-side. |
| 9 | Sensitive attributes aren't serialized | PASS | List payloads drop the heavy `definition` column and expose `has_definition`. |


## Drill-specific enforcement (shipped)

The `drills` table previously had no publication/visibility/approval columns, so
**every** drill was public and there was no draft/private state. Added in
`db/migrate/20261031000001_add_visibility_status_to_drills.rb`:

| Attribute | Column(s) | Values |
|-----------|-----------|--------|
| creator | `created_by_id` (existing) | owner comparison in `authorize_content_owner!` |
| visibility | `visibility` | `shared` (default), `private`, `unlisted` |
| publication status | `status`, `published_at` | `draft` (default), `submitted`, `published`, `archived`, `rejected` |
| approval state | `approved_at`, `approved_by_id` | stamped when a drill is published/rejected |

### Enforced rules

- **Public `index`** (`GET /api/v1/drills`) returns only
  `Drill.published_and_shared` — never `draft`, `private`, `unlisted`,
  `archived`, or `rejected`.
- **Public `show`** (`GET /api/v1/drills/:id`) returns a drill only when it is
  `published_and_shared?`, **or** the caller is the drill's creator. Otherwise
  the response is a 404 (existence is not disclosed).
- **`create`** sets `status` server-side and ignores a client-supplied value:
  a coach starts at `submitted`, anyone else at `draft`. A coach can never
  publish directly through `create`.
- **`update`** restricts `visibility` to the owner or an admin, and `status` to
  a content manager (coach/curator/admin). A non-owner coach cannot change
  another coach's drill visibility.
- The server-rendered pages (`DrillsController#index/show`, `HomeController#index`)
  apply the same `published_and_shared` rule, so the HTML UI cannot leak a
  hidden drill either.

These rules live in the API/model, not the frontend. The SPA's
`user.id === drill.created_by_id` style checks remain cosmetic only; the API
re-checks every mutation and every read.

## Frontend

`src/api.ts` gained `DrillVisibility` / `DrillStatus` types and optional
`visibility`, `status`, `published_at`, and `created_by_id` fields on `Drill`,
plus the matching fields on the admin create/update payloads. No frontend
component grants access — it only renders what the API returns.

## Tests

- `test/controllers/api/v1/drills_controller_test.rb` — index/show exclusion of
  draft/private/unlisted drills, creator-only visibility of hidden drills,
  server-set status on create, and status/visibility mutation guards.
- `test/controllers/api/v1/admin/drills_controller_test.rb` — unchanged admin
  management surface (admins may set `visibility`/`status`).
- `test/models/drill_test.rb`, `test/models/drill_definition_test.rb` — model
  validations and definition schema.
- `test/integration/drill_pages_test.rb` — server-rendered pages with a
  published drill.
- Frontend: `src/api.test.ts`, `src/pages/Drills.test.tsx`,
  `src/pages/settings/Drills.test.tsx`, `src/components/DrillCard.test.tsx`.

## Follow-ups (not shipped here)

1. **Split Neon roles** so cache/queue/cable do not run as the schema owner.
2. **Move local secrets** out of `.env.development*` into encrypted credentials.
3. **Add curator-level drill moderation UI** now that `submitted` exists; today
   publishing is admin-only via the admin surface.
4. **Consider an `approved_by` audit trail** in the admin activity log for
   publish/reject transitions.
