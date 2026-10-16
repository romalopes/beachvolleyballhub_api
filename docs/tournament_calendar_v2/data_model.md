# Tournament Calendar V2 — Data Model

Single migration: `20261009000003_create_tournament_tables.rb` (additive; verified `up` locally).

## Tables

### `tournaments`
`name` (required) · `organisation_id` FK → organisations, `on_delete: :restrict` · `scope` (string enum: e.g. `club`, `regional`, `national`…) · `division_scheme` (e.g. `letter`) · `starts_at` / `ends_at` (required) · `timezone` (required IANA name) · `all_day` (bool, default false) · free-text/contact fields: `description`, `location_name`, `city`, `state`, `country`, `website_url` · `publication_state` (string enum, default `draft`: `draft`, `active`, `cancelled`, `archived`) · `created_by_account_id` FK → accounts · timestamps

### `tournament_divisions`
`tournament_id` FK (cascade) · `letter_level` · `division_number` · `active` (default true; retirement instead of deletion when referenced) · timestamps

### `tournament_participations`
`account_id` FK (cascade) · `tournament_id` FK (cascade) · `role` (string enum: `player`, `coach`, `referee`, `organiser`) · timestamps · uniqueness of (account, tournament) pair enforced at the service layer

### `tournament_watch_links`
`tournament_id` FK (cascade) · ordered links for spectating · timestamps

## Integrity & lock rules

- **Organisation delete guard:** `has_many :tournaments, dependent: :restrict_with_error` — an organisation with tournaments cannot be deleted (verified in `organisation_test.rb`).
- **Scheme lock:** `division_scheme` cannot change once a participation exists (`TournamentUpdateService`).
- **Division locks:** divisions referenced by participations cannot be hard-deleted (retired); retiring the last active division is refused (`TournamentDivisionService`).
- **Enums:** string-backed — unknown values raise `ArgumentError` eagerly (verified in `tournament_test.rb`).
- **Time:** `ends_at > starts_at` validated; all-day tournaments use an exclusive end (next day 00:00 local).

## See also

- Full column listing: `db/schema.rb` and the migration file.
- ERD-level lifecycle: [architecture docs](../architecture/architecture.md).
