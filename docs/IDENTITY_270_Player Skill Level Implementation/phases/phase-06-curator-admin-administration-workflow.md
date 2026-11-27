# Phase 6 — Curator/Admin Administration Workflow

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 6 / Prompt 7)
**Depends on:** Phase 2 (Policy + preview API), Phase 4 (Engine), Phase 5 (Identity + history)

## Goal

Deliver the **10-step Curator/Admin UI & API workflow** for explicit source selection, preview, confirmation, execution, and history review. **Server revalidates authorization, policy, and source at confirmation/execution.** Prevent duplicate submissions. Never accept client-calculated scores/levels.

## 10-step workflow (API + Frontend)

| Step | Action | API / UI |
|------|--------|----------|
| 1 | **Select source type** | `GET /api/v1/player_skill_level_policies/source_options` → `{assessment_sessions: [...], ranking_consolidations: [...]}` |
| 2 | **Select specific session or consolidation** | UI: dropdown/list with status, definition/version, date, player count |
| 3 | **Review compatibility** | `GET /api/v1/player_skill_level_policies/validate_source?source_type=X&source_id=Y` → `{eligible: true, warnings: [], definition_version_match: true}` |
| 4 | **Preview eligible/skipped players** | `POST /api/v1/player_skill_level_policies/preview` (body: source_type, source_id, classification_version) → `{eligible_players: 120, skipped_players: 5, skip_reasons: {...}, level_distribution: {...}, warnings: [...]}` |
| 5 | **Show level distribution & warnings** | UI renders distribution chart + skip reasons |
| 6 | **Explicit confirmation** | UI: "Initiate calculation for 120 players?" (modal, requires typed confirmation) |
| 7 | **Initiate one calculation** | `POST /api/v1/player_skill_level_calculations` (body: policy_id, request_key) → `{calculation_id: 42, status: "processing"}` |
| 8 | **Show progress & counts** | `GET /api/v1/player_skill_level_calculations/:id` (poll) → `{status, processed, skipped, failed, details: [...]}` |
| 9 | **Review calculation history** | `GET /api/v1/player_skill_level_calculations` (list) + detail |
| 10 | **Inspect assignment history** | `GET /api/v1/players/:id/official_skill_level_history` (Phase 5) |

## Implementation checklist

- [ ] **API endpoints** (all Curator/Admin only):
  - `GET /api/v1/player_skill_level_policies/source_options` — list eligible sessions (published) + consolidations (finalized) with metadata
  - `GET /api/v1/player_skill_level_policies/validate_source` — pre-check before preview
  - `POST /api/v1/player_skill_level_policies/preview` — runs adapter in preview mode (no persistence), returns distribution
  - `POST /api/v1/player_skill_level_calculations` — creates calculation record, enqueues job (idempotency key)
  - `GET /api/v1/player_skill_level_calculations/:id` — status + detail
  - `GET /api/v1/player_skill_level_calculations` — paginated history
- [ ] **Frontend screens** (React, behind Curator/Admin route guard):
  - `/admin/skill-levels` — policy list, active badge, "New calculation" button
  - `/admin/skill-levels/new` — 10-step wizard (source type → source pick → validate → preview → confirm → execute → monitor)
  - `/admin/skill-levels/:id` — calculation detail + player-level breakdown
  - `/admin/skill-levels/history` — paginated calculation history
- [ ] **Server revalidation at confirm/execute**:
  - Policy still active
  - Source still eligible (not withdrawn/unfinalized)
  - Classification version still exists
  - Current user still Curator/Admin
- [ ] **Duplicate submission protection**:
  - Client generates `request_key` (UUID) on step 6
  - Server: `Calculation.find_or_create_by(request_key:)` — if `pending/processing` return existing; if `completed` return it
  - UI disables "Initiate" after click, shows spinner
- [ ] **Partial failure reporting**: Calculation detail shows per-player skip/fail reasons (missing score, incomplete, error)
- [ ] **Tests**:
  - Navigation/access (Curator/Admin only)
  - API authorization (403 for Coach/Player)
  - Source validation (ineligible rejected)
  - Preview/execution consistency (same scores → same levels)
  - Duplicate submission (same `request_key` → same record)
  - Partial failure reporting visible
  - Frontend: wizard steps, confirmation modal, polling, error states

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `app/controllers/api/v1/player_skill_level_policies_controller.rb` | Add `source_options`, `validate_source`, `preview` |
| `app/controllers/api/v1/player_skill_level_calculations_controller.rb` | `create`, `show`, `index` |
| `config/routes.rb` | New routes |
| `beachvolleyballhub/src/pages/admin/SkillLevels*.tsx` | Admin pages |
| `beachvolleyballhub/src/components/admin/SkillLevelWizard.tsx` | 10-step wizard |
| `beachvolleyballhub/src/api.ts` | New API calls |
| `test/controllers/api/v1/player_skill_level_policies_controller_test.rb` | Preview/validate tests |
| `test/controllers/api/v1/player_skill_level_calculations_controller_test.rb` | Calculation CRUD tests |
| `beachvolleyballhub/src/__tests__/admin/SkillLevelWizard.test.tsx` | Frontend tests |

## Acceptance criteria

- [ ] `bin/rails test test/controllers/api/v1/player_skill_level_policies_controller_test.rb` passes (preview, validate)
- [ ] `bin/rails test test/controllers/api/v1/player_skill_level_calculations_controller_test.rb` passes (CRUD, idempotency)
- [ ] `npm run test` (frontend) passes for wizard components
- [ ] 10-step flow works end-to-end in staging
- [ ] Server revalidates policy+source+auth at confirm/execute
- [ ] Duplicate `request_key` returns existing calculation (no double-run)
- [ ] Partial failures reported per-player with reasons
- [ ] Coach/Player cannot access any admin endpoints (403)

## Deviations from parent plan (record here)

None yet.