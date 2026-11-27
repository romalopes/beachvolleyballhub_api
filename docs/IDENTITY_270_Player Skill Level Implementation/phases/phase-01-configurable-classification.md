# Phase 1 — Configurable Classification

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 1 / Prompt 2)
**Depends on:** Phase 0 audit complete (canonical identity confirmed, consolidation metric compatible)

## Goal

Implement a configurable `PlayerLevel` catalogue that maps integer scores 0–100 to level codes (B, BB, BBB, A, AA, AAA, AAAA). Store ranges as data, not code. Preserve classification versions for historical interpretation. Restrict edits to Curator/Admin.

## Implementation checklist

- [ ] **Model**: Create or reuse smallest appropriate model (`PlayerLevel` or extend existing). Fields:
  - `code` (string, unique, e.g. "B", "BB", "BBB", "A", "AA", "AAA", "AAAA")
  - `name` (string, e.g. "Beginner", "Developing", "Intermediate", "Advanced", "Competitive", "High Performance", "Elite")
  - `minimum_score` (integer, 0–100, inclusive)
  - `maximum_score` (integer, 0–100, inclusive)
  - `position` (integer, ordering)
  - `active` (boolean, default true)
  - `classification_version` (string or integer, for snapshots)
  - `effective_from` (date, when this version becomes active)
  - timestamps
- [ ] **Validations & constraints**:
  - `minimum_score` ≤ `maximum_score`
  - Bounds within 0–100
  - Active levels cover **entire 0–100 range without gaps or overlaps** (every integer maps to exactly one active level)
  - `code` unique
  - `position` unique among active
  - DB CHECK constraint for score bounds + coverage (or application-level guard with tests)
- [ ] **Idempotent provisioning**: Seed task (`db/seeds/player_levels.rb` or migration `data:`) that creates the initial 7 levels. Re-runnable without duplicates.
- [ ] **Classification versioning**: On any range change, create new `classification_version` records; **never mutate** rows used by past calculations. Snapshot the version on each calculation/assignment.
- [ ] **Shared resolver**: One class/module `PlayerLevels::Resolver` with `resolve(score) → PlayerLevel` (returns nil if no active level covers score — should never happen if coverage valid). Used by calculation engine, preview, backfill, UI.
- [ ] **Authorization**: Pundit `PlayerLevelPolicy` — `index?`/`show?` = authenticated; `create?`/`update?`/`destroy?`/`activate?` = `curator? || admin?`.
- [ ] **API endpoints** (Curator/Admin only for mutations):
  - `GET /api/v1/player_levels` — list active (default) or all
  - `POST /api/v1/player_levels` — create new level (new version)
  - `PATCH /api/v1/player_levels/:id` — update (creates new version row, deactivates old)
  - `GET /api/v1/player_levels/versions` — list classification versions
- [ ] **Tests**:
  - Every integer 0–100 maps to exactly one active level
  - Boundary values (0, 19, 20, 34, 35, 49, 50, 64, 65, 79, 80, 89, 90, 100)
  - Gaps/overlaps detected
  - Duplicate codes rejected
  - Inactive levels excluded from resolver
  - Idempotent seed produces same state
  - Historical version retained (old calculation still resolves via its snapshot version)
  - Authorization: Curator/Admin can mutate; Coach/Player cannot

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `db/migrate/xxx_create_player_levels.rb` | Migration |
| `app/models/player_level.rb` | Model + validations + resolver |
| `app/policies/player_level_policy.rb` | Pundit policy |
| `app/controllers/api/v1/player_levels_controller.rb` | API |
| `config/routes.rb` | Routes |
| `test/models/player_level_test.rb` | Model tests |
| `test/controllers/api/v1/player_levels_controller_test.rb` | Controller tests |
| `db/seeds/player_levels.rb` or data migration | Idempotent provisioning |

## API contract (conceptual)

```json
// GET /api/v1/player_levels
[
  {"code":"B","name":"Beginner","minimum_score":0,"maximum_score":19,"position":1,"active":true,"classification_version":"v1","effective_from":"2025-01-01"},
  {"code":"BB","name":"Developing","minimum_score":20,"maximum_score":34,"position":2,"active":true,"classification_version":"v1","effective_from":"2025-01-01"},
  ...
]

// POST /api/v1/player_levels
{"code":"BBB","name":"Intermediate","minimum_score":35,"maximum_score":49,"position":3}
→ 201 with new record (new classification_version if ranges changed)
```

## Acceptance criteria

- [ ] `bin/rails db:migrate` succeeds
- [ ] `bin/rails test test/models/player_level_test.rb` passes (coverage, boundaries, versioning)
- [ ] `bin/rails test test/controllers/api/v1/player_levels_controller_test.rb` passes (authz, CRUD)
- [ ] Seed is idempotent (`bin/rails db:seed` ×2 = same state)
- [ ] Resolver returns correct level for all 0–100 scores
- [ ] No hardcoded boundaries in any service logic
- [ ] Classification version snapshots preserved for history

## Deviations from parent plan (record here)

None yet.