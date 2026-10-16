# Tournament Calendar V2 — Security Audit

Scope: authentication, authorization, input validation for the tournament feature. Reviewed 2026-10-16 against the workspace source.

## Authentication

- API controllers sit behind the existing token/session auth of `Api::BaseController`; unauthenticated requests are rejected before controller actions run (verified by 401 assertions in `tournaments_integration_test.rb`).
- No tournament endpoint accepts identity from parameters — the acting user comes from `Current` (session/token), never from the payload. Participation self-links only the caller's account (`participate` has no `account_id` parameter surface).

## Authorization

- Writes (`create/update/destroy/divisions/watch_links/lifecycle/participate`) go through `TournamentManagementAuthorization`: `Current.real_user&.admin?` OR `OrganisationAccess.edits_record_by_membership?` on the tournament's organisation. Failures **halt with 403** (verified by controller tests).
- **Impersonation guard:** authorization uses `real_user` — a user acting-as someone else cannot escalate through impersonation (matches the admin-pages convention, e.g. `admin/Tournaments.tsx` checks `real_admin`).
- Read: `draft` tournaments are filtered from the public index unless the caller can manage them; `TournamentQuery` applies this server-side, not client-side.

## Input validation

- All writes pass through service objects (`TournamentCreateService`, `TournamentUpdateService`, `TournamentCancelService`, `TournamentRestoreService`, `TournamentDivisionService`) — no controller writes models directly.
- Strong params; unknown attributes cannot reach models. String-backed enums reject unknown `scope`/`role`/`publication_state` eagerly (`ArgumentError` → handled as validation failure via `InvalidRecord.raise_invalid!`).
- `TournamentTime` parses timezone (IANA validation) and all-day windows; `ends_at > starts_at` enforced.
- Filter inputs are constrained through `TournamentQuery` (whitelisted scopes/levels; sanitised search via Rails query interface — no string interpolation into SQL).
- Forged ownership: an admin of organisation A cannot create/update tournaments under organisation B (organisational membership check, covered by 403 tests).

## Known gaps / accepted risks

- Rate limiting and request-size caps are deployment-level (Render/Rack `Rack::Attack` not configured in-repo) — unchanged for tournaments; public GET endpoints are cacheable and paginated.
- No Playwright browser-level E2E; request-level integration tests cover authorization paths.
- The division "final-active" and scheme-lock rules are enforced in services; the database does not enforce them — acceptable because all writes route through services.

## Verdict

No tournament-specific authorization or validation defects found. Brakeman/bundler-audit run in CI (`ci.yml`) and were green on the last full local test pass.
