# Official Player Skill Level — Phase Documentation Index

**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md`

One implementation document per phase. Each records: the exact work, actual repo touchpoints, tests, acceptance criteria, and deviations from the parent plan.

## Phase Status Tracker

| Phase | Title | Status | Doc | Verified |
|-------|-------|--------|-----|----------|
| 00 | Repository & issue audit (no code changes) | ⏳ Not started | [phase-00-repository-and-issue-audit.md](./phase-00-repository-and-issue-audit.md) | — |
| 01 | Configurable classification | ⏳ Not started | [phase-01-configurable-classification.md](./phase-01-configurable-classification.md) | — |
| 02 | Calculation policy & source selection | ⏳ Not started | [phase-02-calculation-policy-and-source-selection.md](./phase-02-calculation-policy-and-source-selection.md) | — |
| 03 | Curator/Admin authorization | ⏳ Not started | [phase-03-curator-admin-authorization.md](./phase-03-curator-admin-authorization.md) | — |
| 04 | Source adapters & calculation engine | ⏳ Not started | [phase-04-source-adapters-and-calculation-engine.md](./phase-04-source-adapters-and-calculation-engine.md) | — |
| 05 | Identity assignment & history | ⏳ Not started | [phase-05-identity-assignment-and-history.md](./phase-05-identity-assignment-and-history.md) | — |
| 06 | Curator/Admin administration workflow | ⏳ Not started | [phase-06-curator-admin-administration-workflow.md](./phase-06-curator-admin-administration-workflow.md) | — |
| 07 | Player profile & search integration | ⏳ Not started | [phase-07-player-profile-and-search-integration.md](./phase-07-player-profile-and-search-integration.md) | — |
| 08 | Backfill, reconciliation & release | ⏳ Not started | [phase-08-backfill-reconciliation-and-release.md](./phase-08-backfill-reconciliation-and-release.md) | — |
| 09 | Final security & regression review | ⏳ Not started | [phase-09-final-security-and-regression-review.md](./phase-09-final-security-and-regression-review.md) | — |

## Global conventions (enforced in every phase)

| Area | Convention | Reference |
|------|------------|-----------|
| Test framework (API) | Minitest + fixtures — `bin/rails test` | `test/test_helper.rb` |
| Test framework (frontend) | Vitest + React Testing Library — `npm run test` | `beachvolleyballhub/package.json` |
| API auth | Bearer token (`bvb_api_token`) | `beachvolleyballhub/src/api.ts` |
| Roles | `guest, player, coach, curator, admin`; `content_manager? = coach‖curator‖admin` | `app/models/user.rb` |
| Authorization | Pundit — extend policies, never duplicate checks in controllers/React | `app/policies/` |
| Serialization | Inline `serialize(record, detail:)` in controllers | `app/controllers/api/v1/` |
| Status columns | String column + frozen constant (`STATUSES`, `VISIBILITIES`), DB default + CHECK constraint — NOT integer enum | Repo convention |
| Source selection | **BVBH explicitly selects one Assessment Session OR one Ranking Consolidation** — never auto-select latest, never trigger on publish | Parent plan §1, §4, §6 |
| Secrecy | Raw tokens never in logs, errors, audit events, analytics | Parent plan §2.2 |

## Source-selection guarantee (threaded through all phases)

- **Phase 0** confirms the exact `RankingConsolidationResult` metric/scale and eligibility rules.
- **Phase 2** implements `PlayerSkillLevelPolicy` with `source_type` enum + exactly-one source reference; validates lifecycle & compatibility; **forbids automatic selection**.
- **Phase 4** builds two adapters behind one interface — `AssessmentSessionScoreAdapter` reads existing `PlayerAssessment.overall_score`, `RankingConsolidationScoreAdapter` reads the existing consolidation result — **no second averaging engine**.
- **Phase 6** delivers the 10-step Curator/Admin UI: select source type → **pick specific session or consolidation** → preview → confirm → execute → history.
- **Phase 8** backfill uses **only an explicitly approved policy/source**; dry-run preview → authorized confirm → idempotent apply.
- **Phase 9** final review verifies: Curator/Admin-only management; explicit source selection; both adapters work; consolidation metric compatible; no auto-latest; no publish trigger; provenance/history complete; forge-prevention; profile/search use current assignment; `PlayerProfile.level` & tournament division unchanged.