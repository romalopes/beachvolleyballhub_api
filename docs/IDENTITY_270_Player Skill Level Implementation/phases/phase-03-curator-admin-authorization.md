# Phase 3 — Curator/Admin Authorization

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 3 / Prompt 4)
**Depends on:** Phase 2 complete (Policy model + API)

## Goal

Enforce **backend authorization** so only **Curator and Admin** can manage/activate policy, select source, preview, initiate/rerun calculations, and view full administrative reports/history. Coaches continue normal assessment workflows but **cannot** initiate official calculations. Assessment Session publication **must not** update official player levels.

## Implementation checklist

- [ ] **Pundit policies** (extend existing patterns):
  - `PlayerSkillLevelPolicyPolicy` — `manage?`/`activate?`/`preview?`/`calculate?`/`rerun?`/`audit?` = `curator? || admin?`
  - `PlayerSkillLevelCalculationPolicy` — `show?`/`index?` = `curator? || admin?`; `create?` = `curator? || admin?` (via job enqueue)
  - `PlayerSkillLevelAssignmentPolicy` — `index?`/`show?` (history) = `curator? || admin?`; player sees own current via identity endpoint
- [ ] **Controller guards**: All policy/calculation/assignment admin endpoints wrapped with `authorize @record` or `authorize PlayerSkillLevelPolicy, :action?`
- [ ] **Operator derivation**: Current user from `doorkeeper_token.resource_owner` (or session) — **never** accept `operator_id`, `score`, `level_code`, `source_id` from client params for authoritative writes.
- [ ] **Background job authorization**: Jobs (e.g., `PlayerSkillLevelCalculationJob`) only execute **persisted, authorized** `PlayerSkillLevelCalculation` records with `status = 'pending'` and a valid `initiated_by_id` (Curator/Admin). Job re-checks policy active + source eligible at runtime.
- [ ] **Publication decoupling**: Verify `AssessmentSessionPublisher` / `AssessmentSession` callbacks **do not** enqueue official skill level calculation. Remove any such coupling if present.
- [ ] **Existing assessment permissions unchanged**: `AssessmentSessionPolicy`, `AssessmentPolicy`, coach workflows untouched.
- [ ] **Tests** (positive + negative for every operation × role):
  - Admin: all actions allowed
  - Curator: all actions allowed
  - Coach: `manage/activate/preview/calculate/rerun/audit` denied (403)
  - Player: same denied
  - Unauthenticated: 401
  - Forged `operator_id` in params → ignored, derived from auth
  - Forged `score`/`level_code`/`source_id` in calculation create → ignored
  - Job executes only for persisted authorized calculation record
  - Session publish does not create calculation

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `app/policies/player_skill_level_policy_policy.rb` | Policy CRUD/activate/preview/calculate |
| `app/policies/player_skill_level_calculation_policy.rb` | Calculation view/create |
| `app/policies/player_skill_level_assignment_policy.rb` | Assignment history view |
| `app/controllers/api/v1/player_skill_level_policies_controller.rb` | Add `authorize` calls |
| `app/controllers/api/v1/player_skill_level_calculations_controller.rb` | Add `authorize` calls |
| `app/controllers/api/v1/player_skill_level_assignments_controller.rb` | Add `authorize` calls |
| `app/jobs/player_skill_level_calculation_job.rb` | Re-authorize at runtime |
| `test/policies/player_skill_level_policy_policy_test.rb` | Policy tests |
| `test/policies/player_skill_level_calculation_policy_test.rb` | Policy tests |
| `test/policies/player_skill_level_assignment_policy_test.rb` | Policy tests |
| `test/controllers/api/v1/player_skill_level_policies_controller_test.rb` | Authz integration tests |
| `test/controllers/api/v1/player_skill_level_calculations_controller_test.rb` | Authz integration tests |
| `test/jobs/player_skill_level_calculation_job_test.rb` | Job authz tests |

## Acceptance criteria

- [ ] `bin/rails test test/policies/*_policy_test.rb` passes (all role matrices)
- [ ] `bin/rails test test/controllers/api/v1/player_skill_level_*_controller_test.rb` passes (403/401/200 as expected)
- [ ] `bin/rails test test/jobs/player_skill_level_calculation_job_test.rb` passes (job refuses unauthorized records)
- [ ] No assessment session publish callback triggers official calculation (grep for `PlayerSkillLevel` in assessment publish code = none)
- [ ] Coach assessment workflow tests still pass (no regression)

## Deviations from parent plan (record here)

None yet.