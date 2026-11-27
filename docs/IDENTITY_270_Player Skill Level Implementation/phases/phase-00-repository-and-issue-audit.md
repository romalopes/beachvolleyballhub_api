# Phase 0 — Repository & Issue Audit (no code changes)

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 0 / Prompt 1)

## Goal

Inspect both repositories and GitHub issue #270. Establish the technical foundations so every subsequent phase builds on verified facts — **not assumptions**. Deliver an exact file map, current contracts, reusable services, data-model recommendation, API/frontend change list, risks, and test plan.

## Audit checklist (must answer all 9 questions explicitly)

| # | Question | Answer (fill during execution) |
|---|----------|--------------------------------|
| 1 | **What is the canonical player identity record?** (`Person`, `PlayerProfile`, `Account`, or another?) | |
| 2 | **What exact metric does `RankingConsolidationResult` expose?** (average of 0–100 `overall_score`, weighted score, rank/position, percentile, other?) | |
| 3 | **Is the consolidation metric a normalized score on 0–100 scale, or a rank/position?** | |
| 4 | **How are missing/incomplete results handled in consolidation?** (excluded, zero, null, interpolated?) | |
| 5 | **Can consolidations mix Assessment Definition versions?** (if yes, how are weights reconciled?) | |
| 6 | **Which Assessment Session lifecycle states are eligible?** (`published` only? `published` + `withdrawn`?) | |
| 7 | **How are Curator/Admin permissions enforced today?** (Pundit policies? `require_training_manager!`? custom?) | |
| 8 | **What audit/history patterns exist?** (`AdminActivity`, paper_trail, custom tables?) | |
| 9 | **Which search endpoint should expose current official level?** (path, controller, serializer?) | |

## Backend domain model to inspect

| Concern | Files to read | What to extract |
|---------|---------------|-----------------|
| Canonical identity | `app/models/person.rb`, `app/models/player_profile.rb`, `app/models/account.rb`, `db/schema.rb` | Associations, which record is "the player" |
| AssessmentDefinition | `app/models/assessment_definition.rb`, `db/schema.rb` | Categories, versioning, freeze behavior, stable key |
| AssessmentSession | `app/models/assessment_session.rb`, `db/schema.rb` | Lifecycle (`STATUSES`), `published_at`, `assessment_definition_id` |
| PlayerAssessment | `app/models/assessment.rb` (`PlayerAssessment`), `db/schema.rb` | `overall_score` type/precision, completeness, `assessment_session_id` |
| Scoring services | `app/services/assessment_session_score_grid.rb`, `app/services/assessment_session_ranking.rb`, `app/services/assessment_session_publisher.rb` | How `overall_score` is computed, stored, published |
| RankingConsolidation | `app/models/ranking_consolidation.rb`, `app/models/ranking_consolidation_result.rb`, `db/schema.rb` | Result metric, scale, finality, definition/version mixing |
| Consolidation services | `app/services/ranking_consolidation_*.rb` | How results are computed |
| Curator/Admin auth | `app/policies/`, `app/controllers/concerns/`, `app/controllers/api/v1/` | Current role checks, `curator?`, `admin?` |
| Audit/history | `app/models/admin_activity.rb`, `app/controllers/concerns/admin_audit.rb` | Pattern for recording operator + action + entity |
| Profile API | `app/controllers/api/v1/players_controller.rb`, `app/controllers/api/v1/people_controller.rb`, serializers | Where current level should appear |
| Search endpoint | `app/controllers/api/v1/players_controller.rb#index`, query builders | Filter strategy, indexes |

## Frontend to inspect

| Concern | Files to read |
|---------|---------------|
| Admin navigation & role access | `beachvolleyballhub/src/components/layout/`, `beachvolleyballhub/src/App.tsx` routes |
| Assessment Session screens | `beachvolleyballhub/src/pages/AssessmentSessions*.tsx`, `beachvolleyballhub/src/components/assessments/` |
| Ranking Consolidation screens | `beachvolleyballhub/src/pages/Ranking*.tsx`, `beachvolleyballhub/src/components/ranking/` |
| Player profile/identity | `beachvolleyballhub/src/pages/PlayerProfile*.tsx`, `beachvolleyballhub/src/components/player/` |
| Player search filters | `beachvolleyballhub/src/pages/PlayerSearch*.tsx`, filter components |
| API client/types | `beachvolleyballhub/src/api.ts`, TypeScript interfaces |

## Deliverables (commit to this file upon completion)

1. **Exact file map** — every model, service, controller, policy, serializer, route, component, type touched by this feature.
2. **Current contracts** — `PlayerAssessment.overall_score` type/precision, `RankingConsolidationResult` metric/scale, session publication semantics, assessment definition versioning.
3. **Proposed data model** — `PlayerLevel`, `PlayerSkillLevelPolicy`, `PlayerSkillLevelCalculation`, `PlayerSkillLevelAssignment`, canonical identity FK.
4. **API/frontend change list** — new endpoints, new fields, new components, modified search filters.
5. **Risks & migration plan** — consolidation metric incompatibility, identity ambiguity, concurrent calculations, stale jobs, backfill scope.
6. **Test plan** — unit, integration, authorization, frontend, performance.

## Acceptance criteria

- [ ] All 9 questions answered with code references (file:line).
- [ ] Consolidation metric confirmed as **compatible 0–100 normalized score** (or hard stop with decision request).
- [ ] Canonical identity identified and agreed.
- [ ] No code changes made.
- [ ] This document committed; Phase 1 may start.

## Deviations from parent plan (record here)

None yet.