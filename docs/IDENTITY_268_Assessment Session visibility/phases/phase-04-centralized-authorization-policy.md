# Phase 4 — Centralized Authorization Policy

**Status:** ✅ Complete (24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 4)
**Depends on:** Phase 3 complete

## Goal

Extend `AssessmentSessionPolicy` with the full permission matrix so **all** authorization decisions route through Pundit — no duplicate checks in controllers or React.

## Implementation checklist

- [x] Extend `AssessmentSessionPolicy` with:
  - [x] `show?` — per Phase 2 matrix (slug + ID paths)
  - [x] `update?`, `destroy?`, `add_players?`, `remove_players?`, `scores?`, `publish?`, `withdraw?`, `restore?` — management set (coach of record + oversight + admin)
  - [x] `manage_visibility?` — coach of record + admin (+ curator per oversight)
  - [x] `regenerate_share_link?` — same + must be unlisted
  - [x] `Scope#resolve` — managers: all; players: involved sessions (internal/public); others: public
- [x] Wire controller to use `authorize @assessment_session` for member actions
- [x] Wire index to use `policy_scope(AssessmentSession)`
- [x] Add strong params for `visibility` in controller
- [x] Tests: policy specs covering full matrix + scope

## Permission matrix (from Phase 2 — recapped)

| Actor | Public | Unlisted (std path) | Internal | Private |
|-------|--------|---------------------|----------|---------|
| Anonymous | — (login) | — | — | — |
| Registered user, no relation | V | — | — | — |
| Player, uninvolved | V | — | — | — |
| Player, involved | V | — | V | — |
| Coach, unassigned | V | — | — | — |
| Coach of record | V U D M L P | V U D M L P | V U D M L P | V U D M L P |
| Curator | V | V (+mgmt) | V (+mgmt) | V (Q2: oversight parity) |
| Admin | V U D M L P | V U D M L P | V U D M L P | V U D M L P |
| Share-token holder | n/a | V read-only | n/a | n/a |

V=view, U=update, D=destroy, M=manage visibility, L=regenerate link, P=manage participants/scores/publish

## Key implementation notes

- **Organisation mapping (Q1)**: Use coach of record's active `CoachProfile` organisation memberships → their ACTIVE members qualify for `internal`
- **Involved players (Q3)**: `participants.included` only
- **Private audience (Q2)**: Curator = yes (oversight parity)
- **Draft/withdrawn (Q4)**: Coach of record + oversight + admin only, regardless of visibility
- **Scope for players (Q6)**: Involved players get detail + scoped personal list

## Files touched

- `app/policies/assessment_session_policy.rb` — extended with full permission matrix
- `app/controllers/api/v1/assessment_sessions_controller.rb` — added `authorize` calls, `policy_scope` for index, `visibility` to strong params
- `test/policies/assessment_session_policy_test.rb` — 28 tests covering full matrix + scope
- `test/fixtures/assessment_sessions.yml` — updated for policy tests

## Acceptance criteria — all verified

- [x] `bin/rails test test/policies/assessment_session_policy_test.rb` passes (28 tests, 87 assertions)
- [x] Controller uses `authorize` for member actions, `policy_scope` for index
- [x] No authorization logic in controller actions (all in policy)
- [x] Full matrix tested including edge cases (membership removal, assignment removal, etc.)
- [x] Related tests pass: model tests (27), controller tests (3), participant tests (10)