# Phase 4 — Source Adapters & Calculation Engine

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 4 / Prompt 5)
**Depends on:** Phase 2 (Policy), Phase 3 (Authz), Phase 1 (Resolver)

## Goal

Build the **calculation engine** with two **source adapters** behind a common interface. Reuse existing scoring/consolidation logic — **no second averaging engine**. Orchestrator revalidates policy+source at execution, resolves levels via shared `PlayerLevels::Resolver`, records skips/failures, creates assignments, updates current identity. Transactional, idempotent, retryable, concurrency-safe, stale-job guard.

## Implementation checklist

- [ ] **Common adapter interface** (module `PlayerSkillLevels::SourceAdapter`):
  ```ruby
  # Each adapter implements:
  # eligible_players(policy) → Relation of canonical identity records with scores
  #   returns: [{player_id:, score:, source_type:, source_id:}, ...]
  # source_description(policy) → human-readable string for reports
  ```
- [ ] **AssessmentSessionScoreAdapter**:
  - Reads `PlayerAssessment.overall_score` for the policy's selected `AssessmentSession`
  - Only `status = 'published'` sessions
  - Only players with **complete** assessments (all required categories scored)
  - Missing/incomplete → **skipped, reported** — **never converted to zero**
  - Returns canonical player identity ID + score + `source_type: 'assessment_session'` + `source_id: session.id`
- [ ] **RankingConsolidationScoreAdapter**:
  - Reads **existing** `RankingConsolidationResult` metric for the policy's selected `RankingConsolidation`
  - Only `status = 'finalized'` (or equivalent immutable) consolidations
  - **Phase 0 audit must confirm metric is 0–100 normalized score** — if rank/position/incompatible, **stop and report decision required** (do not invent conversion)
  - Missing/incomplete results → skipped, reported
  - Returns canonical player identity ID + score + `source_type: 'ranking_consolidation'` + `source_id: consolidation.id`
- [ ] **Orchestrator** (`PlayerSkillLevels::Calculate` service):
  1. Load `PlayerSkillLevelPolicy` (active) + lock (row lock or advisory lock)
  2. Revalidate: policy active, source eligible, classification version exists
  3. Create `PlayerSkillLevelCalculation` record (`status: 'processing'`, `initiated_by: current_user`, `request_key: SecureRandom.uuid` for idempotency)
  4. Call appropriate adapter → collection of `{player_id, score, source_type, source_id}`
  5. For each: `level = PlayerLevels::Resolver.resolve(score)` (using policy's `classification_version`)
  6. Skip if `level.nil?` (shouldn't happen if coverage valid) → record skip reason
  7. **Transactionally**: create `PlayerSkillLevelAssignment` (history) + update current identity pointer
  8. Update `PlayerSkillLevelCalculation` with counts (`processed`, `skipped`, `failed`), `status: 'completed'` or `'completed_with_errors'`/`'failed'`, `completed_at`
  9. Handle concurrency: advisory lock on policy_id + request_key idempotency; stale job (older `request_key` or superseded calculation) exits early
  10. Retryable: `failed` status + error details; manual or scheduled retry re-runs same calculation record
- [ ] **Idempotency**: Same `request_key` (client-generated or server) → returns existing calculation record if `status ∈ ['pending','processing']`; if `completed`, returns it (no double-execute).
- [ ] **Job**: `PlayerSkillLevelCalculationJob` wraps orchestrator, re-authorizes, handles retries (exponential backoff, max 3).
- [ ] **Tests**:
  - Both adapters return correct player/score tuples
  - Assessment adapter skips incomplete (not zero)
  - Consolidation adapter uses existing metric (no recalc)
  - Orchestrator: boundaries (0, 100, edges), missing/incomplete players, invalid source, ineligible/empty source, duplicate initiation (idempotent), rollback on error, concurrency (two jobs same policy), stale job guard, partial failure/retry, regression

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `app/services/player_skill_levels/source_adapter.rb` | Interface module |
| `app/services/player_skill_levels/assessment_session_score_adapter.rb` | Session adapter |
| `app/services/player_skill_levels/ranking_consolidation_score_adapter.rb` | Consolidation adapter |
| `app/services/player_skill_levels/calculate.rb` | Orchestrator |
| `app/jobs/player_skill_level_calculation_job.rb` | Background job |
| `app/models/player_skill_level_calculation.rb` | Calculation record |
| `test/services/player_skill_levels/assessment_session_score_adapter_test.rb` | Adapter tests |
| `test/services/player_skill_levels/ranking_consolidation_score_adapter_test.rb` | Adapter tests |
| `test/services/player_skill_levels/calculate_test.rb` | Orchestrator tests |
| `test/jobs/player_skill_level_calculation_job_test.rb` | Job tests |

## Data flow

```
Policy (active) → Adapter → [{player_id, score, source_type, source_id}]
       ↓
Resolver.resolve(score) → PlayerLevel
       ↓
Transaction:
  create PlayerSkillLevelAssignment (history)
  update canonical_identity.current_player_skill_level_assignment
  update PlayerSkillLevelCalculation counts/status
```

## Acceptance criteria

- [ ] `bin/rails test test/services/player_skill_levels/*_test.rb` passes
- [ ] `bin/rails test test/jobs/player_skill_level_calculation_job_test.rb` passes
- [ ] Assessment adapter reads existing `overall_score` only — no recalculation
- [ ] Consolidation adapter reads existing `RankingConsolidationResult` only — no recalculation
- [ ] Missing/incomplete → skipped with reason, never zero
- [ ] Idempotent: same `request_key` → same calculation record
- [ ] Concurrency-safe: two concurrent jobs for same policy → one processes, one exits clean
- [ ] Stale job (older `request_key` or superseded policy) → exits without overwriting
- [ ] Retry on `failed` status works

## Deviations from parent plan (record here)

None yet.