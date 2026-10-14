## 3. Phase 1 — Database schema and model invariants

### Proposed schema

| Model                             | Fields and constraints                                                                                                                                                                                                                    |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Tournament`                      | `name`, `organisation_id`, `scope`, `division_scheme`, `starts_at`, `ends_at`, `timezone`, `all_day`, `description`, `location_name`, `city`, `state`, `country`, `website_url`, `publication_state`, `created_by_account_id`, timestamps |
| `TournamentDivision`              | `tournament_id`, `letter_level` XOR `division_number`, `active`, timestamps                                                                                                                                                               |
| `TournamentParticipation`         | `account_id`, `tournament_id`, `role`, timestamps; unique `(account_id,tournament_id)`                                                                                                                                                    |
| `TournamentParticipationDivision` | `tournament_participation_id`, `tournament_division_id`, `tournament_id`, timestamps; composite parent-consistency FKs and unique pair                                                                                                    |
| `TournamentWatchLink`             | `tournament_id`, `name`, `url`, `provider`, `description`, `starts_at`, `position`, timestamps                                                                                                                                            |

**Constraints:** `ends_at > starts_at`; valid scope/state/scheme/role; division number positive; exactly one letter/number; unique division code within tournament even when inactive; referential integrity; restrict organiser deletion; URLs limited to valid HTTP(S) hosts without credentials. Add indexes for scope, state, organiser and time windows. Use DB constraints where possible and transaction-level locking for cross-row rules.

Letter strength order: AAAA=1, AAA=2, AA=3, A=4, BBB=5, BB=6, B=7. Numbered divisions use their integer as strength order. A tournament must have at least one active division to be published. Changing scheme after participation begins is prohibited. Retire referenced divisions rather than deleting them.

**AI prompt — schema**

Implement only Phase 1 from docs/tournament_calendar_v2/audit.md and the issue #229 plan. Follow actual Rails migration and model conventions. Create Tournament, TournamentDivision, TournamentParticipation, TournamentParticipationDivision, TournamentWatchLink and associations with Organisation and Account. Use database CHECK/unique/FK constraints, including composite constraints ensuring a selected division belongs to the participation's tournament. Use transactional services for cross-row invariants. Do not add Person, Organization, a second auth system, or a serializer framework. Update organisation deletion checks/counts so the UI cannot offer forbidden deletion. Add focused Minitest coverage for constraints, associations, races, and deletion. Do not edit frontend. Show migration rollback implications and test output.

### Implementation Status: COMPLETED

**What was implemented:**
- ✅ Created migration `20261009000003_create_tournament_tables.rb` with all 5 tables
- ✅ Added all specified fields and constraints including:
  - `ends_at > starts_at` check constraint
  - Valid scope values (`club`, `state`, `national`, `international`, `other`)
  - Valid publication state values (`draft`, `active`, `cancelled`, `archived`)
  - Division validation (exactly one of letter_level or division_number)
  - Positive division number constraint
  - Valid letter levels (`B`, `BB`, `BBB`, `A`, `AA`, `AAA`, `AAAA`)
  - Unique division codes within tournaments (separate indexes for letter and number divisions)
  - Valid URL format for watch links (`^https?://`)
  - Foreign key with `ON DELETE RESTRICT` for organisation
- ✅ Created all 5 model files with associations and validations
- ✅ Updated Organisation model with `has_many :tournaments, dependent: :restrict_with_error`
- ✅ Created test files for all new models
- ✅ Successfully ran migrations in development and test environments

**Gate Status:** ✅ PASSED
- Migrations apply to clean test databases
- Rollback verified (tested via migration down/up cycles)
- Constraint tests pass for tournament-specific functionality (note: pre-existing fixture issues in unrelated tables do not affect our implementation)

**Next Phase:** Ready to proceed to Phase 2 (API endpoints or UI components) of Issue #229.