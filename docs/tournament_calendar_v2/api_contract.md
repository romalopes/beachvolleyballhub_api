# Tournament Calendar V2 — API Contract

Base: `/api/v1` · JSON only · Bearer token auth (`Authorization: Bearer …`). Endpoints verified with `bin/rails routes -g tournament`.

## Tournaments

| Method | Path | Action | Notes |
| --- | --- | --- | --- |
| GET | `/tournaments` | index | Public directory. Filters: `search`, `scope`, `organisation_ids[]` (or legacy `organisation_id`), `division_scheme`, `letter_levels[]`, `division_numbers[]`, `location`, `temporal_status`, `mine=1`, `publication_state`, `starts_at`, `ends_at`, `page`, `per_page` (default 25) |
| GET | `/tournaments/options` | options | Filter dropdown data: `scopes`, `schemes`, `ordered_levels`, `participation_roles` |
| GET | `/tournaments/:id` | show | Detail incl. `divisions`, `participations`, `watch_links`; `draft` visible only to organisation admins |
| POST | `/tournaments` | create | Admin of the organisation; starts in `draft` |
| PATCH/PUT | `/tournaments/:id` | update | Scheme locks after first participation (409-class error) |
| DELETE | `/tournaments/:id` | destroy | Only when unused (no participations); otherwise blocked |

## Lifecycle

| Method | Path | Effect |
| --- | --- | --- |
| PATCH | `/tournaments/:id/publish` | `draft → active` |
| PATCH | `/tournaments/:id/archive` | `→ archived` |
| POST | `/tournaments/:id/cancel` | `→ cancelled` (participations notified/ended per service) |
| POST | `/tournaments/:id/restore` | `cancelled/archived → active` |

Lifecycle actions require organisation admin/management authorisation; insufficient permission returns **403** with a halting error body.

## Nested resources

| Method | Path |
| --- | --- |
| POST | `/tournaments/:tournament_id/divisions` |
| PATCH/PUT/DELETE | `/tournaments/:tournament_id/divisions/:id` |
| POST | `/tournaments/:tournament_id/watch_links` |
| PATCH/PUT/DELETE | `/tournaments/:tournament_id/watch_links/:id` |

Divisions referenced by participations are code-locked (retire, not delete) and the final active division cannot be retired; watch links support ordering.

## Participation

| Method | Path | Effect |
| --- | --- | --- |
| POST | `/tournaments/:id/participate` | Body `{ role }` (`player`, `coach`, `referee`, `organiser`); self-links the caller's account; invalid role → validation error |
| DELETE | `/tournaments/:id/participate` | Removes the caller's participation |

## Conventions

- Validation failures: **422** with Rails-style `{ errors: … }` (services raise through `InvalidRecord.raise_invalid!`).
- Unauthorised: **403**; unauthenticated: **401**; not found: **404**.
- `TournamentQuery` is the single source of filtering/pagination; `organisation_ids[]` is the canonical multi-org param.
