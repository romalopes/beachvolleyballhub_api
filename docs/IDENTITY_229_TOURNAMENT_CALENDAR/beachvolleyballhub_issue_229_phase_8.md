## 10. Phase 8 — Admin forms and organisation integration

Provide admin-only create/edit forms for name, organiser, scope, scheme, divisions, dates, timezone, all-day, location, description, website and lifecycle actions. Admin can add/deactivate divisions and reorder/add/remove watch links. Prevent final active division removal and scheme changes after participation. Search/select only eligible existing organisations; preserve their hierarchy and access controls. Display organiser-linked tournaments on organisation details **only where existing organisation access rules permit**; do not expose private rosters.

**AI prompt — administration**

Build tournament admin CRUD and division/watch-link management using the application's existing admin UI, role guards, forms and Organisation selector. Respect backend permissions; client guards are not security controls. Support atomic nested creation, timezone/DST validation, edit conflicts, confirmation for cancel/archive/delete, safe URL links, and explicit errors when a referenced division cannot be removed. Extend Organisation details and deletion-blocker UI only as authorized by existing code. Add React tests and Rails request coverage for critical flows.

**Gate:** frontend build and integration tests pass; admin flows work and respect backend permissions.

### Implementation status — October 16, 2026

Implemented across the React client (the tournament, division and watch-link endpoints already existed from Phase 4):

- The admin tournament form now manages **divisions** — add a letter level or division number (matching the tournament's scheme), deactivate/activate, and remove — alongside the existing create/edit fields.
- It also manages **ordered watch links** — add (name/url/provider), reorder (move up/down), and remove.
- **Lifecycle actions** (publish, archive, cancel, restore, delete) are available on the edit form, with confirmation for the destructive cancel/archive/delete actions.
- The typed API client (`src/api.ts`) gained `createDivision`/`updateDivision`/`deleteDivision`, `createWatchLink`/`updateWatchLink`/`deleteWatchLink`, and `cancelTournament`/`restoreTournament`/`deleteTournament`; the `WatchLink` type was aligned with the server payload (`name`, `provider`, `description`, `starts_at`).
- Organisation deletion remains guarded server-side (`has_many :tournaments, dependent: :restrict_with_error`), so deleting an organisation that still has tournaments is refused with an error the Organisation detail page already surfaces. Client-side `can_delete`/role guards remain presentational; the server is authoritative.

### Verification — October 16, 2026

- Backend tournament suite passes: **107 tests, 0 failures, 0 errors** — models, services, participation/detail integration, plus the new `tournament_divisions_controller_test.rb` and `tournament_watch_links_controller_test.rb` request tests (admin add/deactivate/remove/reorder and non-admin 403 coverage).
- Frontend build (`npm run build`) succeeds; frontend typecheck (`tsc -b`) passes.
- New `TournamentForm` admin tests pass (**3 tests**): division/watch-link/lifecycle sections render, adding a division calls the API, and cancelling a tournament (after confirmation) calls the API.
- Note: a full `vitest` run additionally reports 24 pre-existing `src/api.test.ts` failures from a local `.env.local` `VITE_API_BASE_URL=http://localhost:3001/api/v1` (part of the observability/local-dev setup) — it makes the client emit absolute URLs the existing URL assertions don't expect. This predates and is unrelated to these Phase 8 changes; tracked for Phase 9.