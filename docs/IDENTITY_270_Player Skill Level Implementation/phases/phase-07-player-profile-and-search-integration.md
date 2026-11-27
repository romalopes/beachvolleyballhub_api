# Phase 7 — Player Profile & Search Integration

**Status:** ⏳ Not started
**Parent plan:** `../beachvolleyballhub_official_player_skill_level_plan_v2.md` (§6 Phase 7 / Prompt 8)
**Depends on:** Phase 5 (Identity + current level API)

## Goal

Integrate the official Player Skill Level into **player identity/profile display** and **player search/filtering**. Keep coach-entered `PlayerProfile.level` and tournament division **completely separate**. Respect privacy/visibility. Expose stable API contract for future features.

## Implementation checklist

### Profile display (API + Frontend)

- [ ] **API** (already in Phase 5): `GET /api/v1/players/:id` includes `current_official_skill_level` object (or `null`)
- [ ] **Visibility rules** (reuse existing profile visibility):
  - Public profile: show code/name only
  - Authenticated (player/coach): show code/name + score + calculated_at
  - Curator/Admin: show full + source_type + source_id
  - If unassessed (`null`): display "Unassessed" — **never** default to Beginner
- [ ] **Frontend player profile page**:
  - Show official skill level badge (code + name, color-coded by level)
  - Tooltip/detail: score, date, source (if permitted)
  - **Separate section** for "Coach-entered level" (`PlayerProfile.level`)
  - **Separate** for "Tournament division"
  - No visual conflation of the three concepts
- [ ] **Tests**: profile display for each role; unassessed state; separation from coach level & division

### Search & filtering

- [ ] **API**: `GET /api/v1/players?official_skill_level[]=AA&official_skill_level[]=AAA`
  - Filter by **current** assignment only (not history)
  - Support single or multiple codes (OR logic, consistent with existing filters)
  - Combine with other filters (name, location, etc.)
- [ ] **Indexes**: Add DB index on `player_skill_level_assignments.player_level_id` + `player_identity_id` for current-assignment lookups (or materialized view / denormalized column on identity if query plan demands)
- [ ] **Frontend player search page**:
  - Add "Official Skill Level" multi-select filter
  - Show filter chips with level codes
  - Results show official level badge
- [ ] **Privacy**: Filter respects same visibility as profile (e.g., players with private profiles excluded from search for unauthorized users)
- [ ] **Tests**:
  - Single code filter returns correct players
  - Multiple codes (OR) works
  - Historical assignments do NOT cause false matches
  - Unassessed players excluded unless explicitly filtered (decide: `official_skill_level=unassessed` param?)
  - Query performance (EXPLAIN) — no N+1, indexes used
  - Visibility respected

### Stable forward-looking contract

- [ ] Document the `current_official_skill_level` JSON shape in API docs
- [ ] Versioned endpoint path (`/api/v1/`) — future v2 can extend without breaking
- [ ] No implementation of partner search, training groups, recommendations, analytics in this phase

## Files to touch (estimated)

| File | Purpose |
|------|---------|
| `app/controllers/api/v1/players_controller.rb` | Add search filter logic |
| `app/models/player_skill_level_assignment.rb` | Scopes for current assignment filtering |
| `db/migrate/xxx_add_index_for_skill_level_search.rb` | Search indexes |
| `beachvolleyballhub/src/pages/PlayerProfile.tsx` | Profile display |
| `beachvolleyballhub/src/pages/PlayerSearch.tsx` | Search filter |
| `beachvolleyballhub/src/components/player/OfficialSkillLevelBadge.tsx` | Reusable badge |
| `test/controllers/api/v1/players_controller_test.rb` | Search filter tests |
| `beachvolleyballhub/src/__tests__/player/OfficialSkillLevelBadge.test.tsx` | Frontend tests |

## Acceptance criteria

- [ ] Profile shows official code/name/score/date (access-gated), "Unassessed" when null
- [ ] Coach-entered `PlayerProfile.level` displayed separately, unchanged
- [ ] Tournament division displayed separately, unchanged
- [ ] Search filters by current official level (single + multi), current-only
- [ ] Historical assignments never match search
- [ ] Indexes added, query plans show index usage
- [ ] Visibility/privacy respected in both profile and search
- [ ] API contract documented and stable

## Deviations from parent plan (record here)

None yet.