# Phase 5 — Identity Assignment & History

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 5 / Prompt 6)
**Depends on:** Phase 0 (canonical identity confirmed), Phase 4 (calculation engine)

## Goal

Persist the **official Player Skill Level** on the **canonical player identity** (identified in Phase 0). Retain **append-only historical assignments** with full provenance. Represent "no assignment" as null/Unassessed. Update current assignment transactionally. **Never overwrite `PlayerProfile.level` or tournament division.** Prevent client writes to official fields.

## Implementation checklist

- [ ] **Canonical identity**: Confirm Phase 0 answer — e.g., `Person` (if 1:1 with player) or `PlayerProfile`. Add associations:
  - `has_one :current_player_skill_level_assignment, class_name: 'PlayerSkillLevelAssignment'`
  - `has_many :player_skill_level_assignments, class_name: 'PlayerSkillLevelAssignment'` (history)
- [ ] **Model**: `PlayerSkillLevelAssignment` (append-only history):
  - `player_identity_id` (FK to canonical identity, e.g. `person_id` or `player_profile_id`)
  - `player_level_id` (FK to `PlayerLevel` — the level at time of calculation)
  - `level_code_snapshot` (string, denormalized: "B", "BB", "A", etc.)
  - `level_name_snapshot` (string, denormalized: "Beginner", "Advanced", etc.)
  - `score` (integer, 0–100, the source score used)
  - `source_type` (string: `assessment_session`, `ranking_consolidation`)
  - `source_id` (bigint, FK to session/consolidation)
  - `player_skill_level_policy_id` (FK to policy used)
  - `classification_version_snapshot` (string, e.g. "v1")
  - `player_skill_level_calculation_id` (FK to calculation run)
  - `calculated_at` (datetime, when calculation completed)
  - `initiated_by_id` (FK to User — Curator/Admin who triggered)
  - timestamps
  - Indexes: `[player_identity_id, calculated_at]`, `[player_skill_level_calculation_id]`
- [ ] **Current pointer**: On canonical identity, `current_player_skill_level_assignment_id` (FK, nullable). Updated **transactionally** with assignment insert.
- [ ] **Unassessed state**: `current_player_skill_level_assignment_id = NULL` → UI shows "Unassessed". No default level.
- [ ] **Provenance**: Every assignment captures score, source, policy/classification version, calculation, operator, timestamp.
- [ ] **Write protection**: No `accepts_nested_attributes_for`, no mass-assignment permits for official fields. Only calculation engine (server) creates assignments.
- [ ] **API exposure** (read-only for players/coaches, full for Curator/Admin):
  - `GET /api/v1/players/:id` → includes `current_official_skill_level: {code, name, score, calculated_at, source_type, source_id}` (nil if unassessed)
  - `GET /api/v1/players/:id/official_skill_level_history` → paginated assignments (Curator/Admin) or current only (player/coach)
- [ ] **Tests**:
  - Current result exposed on identity
  - Append-only history (multiple calculations → multiple assignments)
  - Provenance fields all populated
  - Unassessed = null (no default)
  - Forged writes rejected (403/422)
  - Identity association correct (Phase 0 canonical record)
  - `PlayerProfile.level` unchanged (verify column untouched)
  - Tournament division unchanged

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `db/migrate/xxx_add_official_skill_level_to_<canonical_identity>.rb` | Add `current_player_skill_level_assignment_id` FK |
| `db/migrate/xxx_create_player_skill_level_assignments.rb` | History table |
| `app/models/player_skill_level_assignment.rb` | Model |
| `app/models/<canonical_identity>.rb` | Add associations |
| `app/controllers/api/v1/players_controller.rb` | Expose current level in show |
| `app/controllers/api/v1/player_skill_level_assignments_controller.rb` | History endpoint |
| `test/models/player_skill_level_assignment_test.rb` | Model tests |
| `test/controllers/api/v1/players_controller_test.rb` | Current level exposure |
| `test/controllers/api/v1/player_skill_level_assignments_controller_test.rb` | History tests |

## API contract (conceptual)

```json
// GET /api/v1/players/123
{
  "id": 123,
  "name": "Ana Silva",
  "current_official_skill_level": {
    "code": "AA",
    "name": "Competitive",
    "score": 72,
    "calculated_at": "2025-06-15T10:30:00Z",
    "source_type": "assessment_session",
    "source_id": 42
  },
  "coach_entered_level": "Advanced",  // PlayerProfile.level — separate
  "tournament_division": "AA"         // separate
}

// GET /api/v1/players/123/official_skill_level_history
[
  {"code":"AA","name":"Competitive","score":72,"calculated_at":"2025-06-15T10:30:00Z","source_type":"assessment_session","source_id":42,"policy_version":"v1","calculation_id":5},
  {"code":"A","name":"Advanced","score":58,"calculated_at":"2024-11-20T14:00:00Z","source_type":"ranking_consolidation","source_id":7,"policy_version":"v1","calculation_id":2}
]
```

## Acceptance criteria

- [ ] `bin/rails db:migrate` succeeds
- [ ] `bin/rails test test/models/player_skill_level_assignment_test.rb` passes
- [ ] `bin/rails test test/controllers/api/v1/players_controller_test.rb` passes (current level exposed)
- [ ] `bin/rails test test/controllers/api/v1/player_skill_level_assignments_controller_test.rb` passes (history)
- [ ] History is append-only (no UPDATE on assignments)
- [ ] Current pointer updated transactionally with new assignment
- [ ] Unassessed = null, no default level assigned
- [ ] `PlayerProfile.level` column never written by this feature
- [ ] Tournament division column never written by this feature

## Deviations from parent plan (record here)

None yet.