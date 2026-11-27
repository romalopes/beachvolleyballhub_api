# Phase 9 — Final Security & Regression Review

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 9 / Prompt 10)
**Depends on:** Phases 0–8 complete

## Goal

Perform a **complete end-to-end security, architecture, and regression review** across API and frontend. Verify **all 16 acceptance criteria** from the parent plan. Run actual tests, lint, type checks, migrations, production builds. Report **only checks actually executed**.

## Verification checklist (map to parent plan §9 acceptance criteria)

| # | Acceptance criterion | Verification method | Result (fill during execution) |
|---|---------------------|---------------------|--------------------------------|
| 1 | Only Curator/Admin can manage or initiate official calculations | Policy tests + controller tests + job tests | |
| 2 | BVBH explicitly selects the authoritative source | Policy model validates exactly one source; UI requires selection; no auto-latest | |
| 3 | Both selected Assessment Session and selected Ranking Consolidation are supported | Two adapters work; preview/execute for both source types | |
| 4 | Existing scoring and consolidation logic is reused | Adapters read `PlayerAssessment.overall_score` & `RankingConsolidationResult` — no recalc code | |
| 5 | Consolidation metric is proven compatible before classification | Phase 0 audit confirmed 0–100 normalized score; adapter stops if not | |
| 6 | Levels/ranges are configurable | `PlayerLevel` model + API + seed; no hardcoded boundaries | |
| 7 | Every calculation records source, score, policy/classification version, operator, timestamp | `PlayerSkillLevelCalculation` + `PlayerSkillLevelAssignment` fields populated | |
| 8 | Current official level is part of canonical player identity | `current_player_skill_level_assignment` on canonical identity (Phase 0) | |
| 9 | Historical assignments remain available | `PlayerSkillLevelAssignment` append-only history; API returns history | |
| 10 | Publishing an Assessment Session does not automatically change official level | Grep: no callbacks/jobs from `AssessmentSession` publish → `PlayerSkillLevel` | |
| 11 | Missing/incomplete scores are not converted to zero | Adapters skip with reason; tests assert no zero substitution | |
| 12 | `PlayerProfile.level` remains unchanged | Migration doesn't touch it; no code writes to it; test asserts | |
| 13 | Tournament division remains independent | No code touches tournament division; test asserts | |
| 14 | Profile and search use the current official assignment | Profile API + search filter use `current_player_skill_level_assignment` | |
| 15 | API permissions and privacy rules are enforced | Pundit policies + controller authz tests + visibility rules in serializers | |
| 16 | Backfill is controlled, auditable and idempotent | Rake tasks dry-run/confirm; idempotent; audit trail via calculation records | |

## Technical quality gates (must pass)

| Gate | Command | Expected |
|------|---------|----------|
| Backend tests | `bin/rails test` | All pass (including new test files) |
| Frontend tests | `cd beachvolleyballhub && npm run test` | All pass |
| Frontend lint | `cd beachvolleyballhub && npm run lint` | No errors |
| Type check | `cd beachvolleyballhub && npm run typecheck` (or `tsc --noEmit`) | No errors |
| Migrations | `bin/rails db:migrate` (dev + staging) | No errors, reversible |
| Production build | `cd beachvolleyballhub && npm run build` | Succeeds |
| Security scan | `bin/brakeman` (or CI equivalent) | No new high/critical |
| N+1 query check | `bullet` in test env / manual EXPLAIN | No new N+1 in profile/search |
| Race condition review | Code review: advisory locks, idempotency keys, transactional updates | Documented safe |

## Deliverables (commit to this file)

1. **Changed-file summary** — list every file added/modified across all phases
2. **Test results** — actual output of `bin/rails test` and `npm run test` (pass counts)
3. **Migration list** — each migration file + purpose
4. **API contract** — final endpoints, request/response shapes
5. **Permission matrix** — final role × action table
6. **Unresolved risks** — any items not fully mitigated
7. **Deployment & rollback plan** — exact commands, order, verification steps
8. **Rollback verification** — `db:rollback` tested, data integrity confirmed

## Final sign-off

- [ ] All 16 acceptance criteria verified with evidence
- [ ] All quality gates pass (commands actually run, output captured)
- [ ] No unrelated refactors included
- [ ] No unexecuted checks claimed as passed
- [ ] Document ready for release approval

## Deviations from parent plan (record here)

None yet.