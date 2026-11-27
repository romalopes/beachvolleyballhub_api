# Phase 2 — Calculation Policy & Source Selection

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 2 / Prompt 3)
**Depends on:** Phase 1 complete (PlayerLevel catalogue + resolver), Phase 0 audit (consolidation metric confirmed compatible)

## Goal

Implement the **BVBH-controlled `PlayerSkillLevelPolicy`** that explicitly binds **one selected source** — either an **Assessment Session** or a **Ranking Consolidation** — plus the classification version. **No automatic selection, no calculation on policy change.** Preserve policy snapshots for every calculation.

## Implementation checklist

- [ ] **Model**: `PlayerSkillLevelPolicy` with fields:
  - `source_type` (string, enum: `assessment_session`, `ranking_consolidation`)
  - `source_id` (bigint, polymorphic-ish — exactly one of `assessment_session_id` or `ranking_consolidation_id` via validation)
  - `assessment_definition_id` (optional, for session: the definition/version the session uses)
  - `classification_version` (string, FK to `PlayerLevel` snapshot version, e.g. "v1")
  - `active` (boolean, default false — only one active global policy at a time unless multi-scope needed)
  - `configured_by_id` (FK to User, Curator/Admin who created)
  - `activated_by_id` (FK to User, Curator/Admin who activated)
  - `activated_at` (datetime)
  - `notes` (text, optional reason)
  - timestamps
- [ ] **Validations**:
  - Exactly one of `assessment_session_id` / `ranking_consolidation_id` present matching `source_type`
  - Source record exists and is in eligible lifecycle state:
    - `AssessmentSession`: `status = 'published'` AND `published_at` present
    - `RankingConsolidation`: `status = 'finalized'` (or equivalent immutable state)
  - If `source_type = 'assessment_session'`: session's `assessment_definition_id` matches policy's `assessment_definition_id` (if set)
  - Classification version exists in `PlayerLevel` catalogue
  - Only one `active` policy at a time (global scope; add scope column if Phase 0 audit demands)
- [ ] **Policy snapshots**: On any change to an active policy, **create a new policy record** (version) rather than mutating. Calculations reference the exact policy record used.
- [ ] **API endpoints** (Curator/Admin only):
  - `GET /api/v1/player_skill_level_policies` — list all (with source details)
  - `GET /api/v1/player_skill_level_policies/:id` — show with source preview data
  - `POST /api/v1/player_skill_level_policies` — create (inactive draft)
  - `PATCH /api/v1/player_skill_level_policies/:id` — update draft (cannot mutate active; creates new version)
  - `POST /api/v1/player_skill_level_policies/:id/activate` — activate (sets `active=true`, deactivates others)
  - `GET /api/v1/player_skill_level_policies/:id/preview` — **preview calculation** (see Phase 4/6)
- [ ] **Source eligibility queries** (reusable for UI selectors):
  - `AssessmentSession.eligible_for_skill_level` → published sessions with complete `PlayerAssessment.overall_score` for at least one player
  - `RankingConsolidation.eligible_for_skill_level` → finalized consolidations with compatible metric
- [ ] **Tests**:
  - Valid policy creation for both source types
  - Missing/wrong source ID rejected
  - Both source IDs provided rejected
  - Ineligible source (draft session, unfinalized consolidation) rejected
  - Incompatible definition/version rejected
  - Policy change does not mutate old calculations (snapshot retained)
  - Only one active policy
  - Authorization: Curator/Admin only

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `db/migrate/xxx_create_player_skill_level_policies.rb` | Migration |
| `app/models/player_skill_level_policy.rb` | Model + validations + scopes |
| `app/policies/player_skill_level_policy_policy.rb` | Pundit policy |
| `app/controllers/api/v1/player_skill_level_policies_controller.rb` | API |
| `config/routes.rb` | Routes |
| `test/models/player_skill_level_policy_test.rb` | Model tests |
| `test/controllers/api/v1/player_skill_level_policies_controller_test.rb` | Controller tests |

## API contract (conceptual)

```json
// POST /api/v1/player_skill_level_policies
{
  "source_type": "assessment_session",
  "source_id": 42,
  "assessment_definition_id": 5,
  "classification_version": "v1",
  "notes": "Season 2025 official assessment"
}
→ 201 inactive draft

// POST /api/v1/player_skill_level_policies/1/activate
→ 200 active, others deactivated

// GET /api/v1/player_skill_level_policies/1/preview
{
  "eligible_players": 120,
  "skipped_players": 5,
  "skip_reasons": {"missing_score": 3, "incomplete_assessment": 2},
  "level_distribution": {"B": 10, "BB": 25, "BBB": 40, "A": 30, "AA": 15, "AAA": 5, "AAAA": 0},
  "warnings": ["5 players skipped"]
}
```

## Acceptance criteria

- [ ] `bin/rails db:migrate` succeeds
- [ ] Model validates: exactly one source ref, eligible lifecycle, compatible definition/version
- [ ] Policy activation deactivates others; snapshots preserved
- [ ] No calculation triggered by create/update/activate
- [ ] Preview endpoint returns eligible/skipped counts + level distribution (delegates to Phase 4 engine)
- [ ] Authorization: Curator/Admin only for all mutations
- [ ] Tests pass

## Deviations from parent plan (record here)

None yet.