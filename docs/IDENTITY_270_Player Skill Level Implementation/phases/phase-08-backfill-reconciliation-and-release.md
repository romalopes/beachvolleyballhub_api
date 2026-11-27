# Phase 8 — Backfill, Reconciliation & Release

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 8 / Prompt 9)
**Depends on:** Phases 1–7 complete (full feature working for new calculations)

## Goal

Provide **safe, idempotent, auditable historical backfill** for players who should have official levels from past approved sources. **Never infer source from latest date or display name.** Require explicitly approved BVBH policy/source. Dry-run preview → authorized confirm → idempotent apply. Reconcile stale/missing projections. Document deployment/rollback.

## Implementation checklist

- [ ] **Rake tasks** (namespace `player_skill_levels`):
  - `bin/rails player_skill_levels:preview` — dry-run using **active policy** (or explicit `POLICY_ID=` env):
    - For each eligible player: output `player_id, player_name, source_type, source_id, score, proposed_level_code, skip_reason`
    - Summary: total, eligible, skipped (by reason), level distribution
    - **No writes**
  - `bin/rails player_skill_levels:recalculate` — execution mode:
    - Requires `CONFIRM=yes` env (or interactive prompt)
    - Uses same `PlayerSkillLevels::Calculate` orchestrator as runtime
    - Batches (e.g., `find_in_batches(500)`) to avoid memory/timeout
    - Creates `PlayerSkillLevelCalculation` record (status `backfill`) + assignments
    - Clear reporting: processed, skipped, failed, errors
    - **Idempotent**: re-running same policy produces same assignments (upsert on `player_identity_id + calculation_id` or unique constraint)
    - Safe retry: failed players logged, can re-run with `RETRY_FAILED=yes`
- [ ] **Reconciliation capability**:
  - `bin/rails player_skill_levels:reconcile` — detects players with:
    - No current assignment but eligible source exists in active policy
    - Current assignment points to superseded calculation (policy changed)
    - Assignment missing provenance fields
  - Reports discrepancies; optional `--fix` applies corrections via orchestrator
- [ ] **Guardrails**:
  - **Never** modify `PlayerProfile.level` (coach-entered)
  - **Never** modify tournament division
  - **Never** invent publication timestamps for legacy sessions where actual `published_at` cannot be established (skip with reason)
  - **Never** auto-select source — only uses **explicitly approved active policy**
  - Dry-run has **zero side effects** (verified by test)
- [ ] **Tests**:
  - Dry-run makes no writes (DB snapshots before/after identical)
  - Execution is idempotent (run 2× = same state)
  - Failures visible & retryable
  - Unrelated assessments (wrong definition, draft sessions) excluded
  - `PlayerProfile.level` & tournament division unchanged (assert in test)
- [ ] **Staging verification**:
  - Run preview → review output with BVBH
  - Run recalculate on staging copy
  - Spot-check assignments vs. manual calculation
  - Verify profile/search show correct levels
- [ ] **Deployment & rollback docs**:
  - Migration order (phases 1–5 migrations first, then backfill task)
  - Monitoring: calculation job queue, error rate, assignment counts
  - Retry: `player_skill_levels:recalculate RETRY_FAILED=yes`
  - Rollback: `db:rollback` migrations + delete backfill calculations/assignments (scope by `calculation.source_type = 'backfill'`)

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `lib/tasks/player_skill_levels.rake` | Preview, recalculate, reconcile tasks |
| `app/services/player_skill_levels/backfill.rb` | Shared backfill logic (used by task + reconcile) |
| `test/tasks/player_skill_levels_task_test.rb` | Rake task tests (dry-run, idempotent, retry) |
| `DEPLOYMENT.md` (or update existing) | Backfill deployment/rollback steps |

## Acceptance criteria

- [ ] `bin/rails player_skill_levels:preview` runs, outputs CSV/JSON/table, **zero DB writes**
- [ ] `bin/rails player_skill_levels:recalculate CONFIRM=yes` applies backfill, idempotent
- [ ] `bin/rails player_skill_levels:reconcile` reports discrepancies
- [ ] Tests prove: dry-run no side effects, execution idempotent, failures retryable, unrelated excluded
- [ ] `PlayerProfile.level` and tournament division verified unchanged
- [ ] Staging run completes, spot-checks pass
- [ ] Deployment/rollback documented

## Deviations from parent plan (record here)

None yet.