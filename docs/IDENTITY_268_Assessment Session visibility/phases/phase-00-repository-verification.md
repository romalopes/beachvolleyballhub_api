# Phase 0 — Repository & Working-Tree Verification

**Status:** ✅ Complete (24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 0)

## Goal

Confirm the correct repositories, branches, working trees, and project instructions before touching code.

## Verified workspace

| Item | API | Frontend |
|------|-----|----------|
| Directory | `beachvolleyballhub_api/` | `beachvolleyballhub/` |
| Branch | `main` (HEAD `837faa2 changes`) | `main` (HEAD `eb43036 changes`) |
| Working tree | Clean (`git status --porcelain` empty) | Clean |
| Stack | Ruby 3.4.2 (`.ruby-version`), Rails `~> 8.1.3`, Pundit `~> 2.5`, PostgreSQL | React `^19.2.8`, TypeScript `~6.0.2`, Vite `^8.2.2`, Vitest |
| Tests | Minitest + fixtures — `bin/rails test` | `npm run test` (Vitest + RTL), `npm run lint`, `npm run build` |

## Conventions confirmed (apply to every phase)

| Area | Convention | Reference |
|------|------------|-----------|
| Authorization | Pundit, one policy per resource, `ApplicationPolicy` base with effective-user/impersonation semantics | `app/policies/`, `app/policies/application_policy.rb` |
| Serialization | Inline private `serialize(record, detail:)` in API controllers — no serializer classes | `app/controllers/api/v1/assessment_sessions_controller.rb` |
| Auth | Bearer token (`bvb_api_token` in frontend localStorage) → `Current.user` | `beachvolleyballhub/src/api.ts` |
| Roles | `guest, player, coach, curator, admin` via `Role`/`UserRole`; helpers on `User` | `app/models/user.rb` |
| Status columns | String columns + frozen constants (`STATUSES`, `VISIBILITIES`) — NOT Rails integer enums | `app/models/assessment_session.rb`, `app/models/coach_profile.rb` |
| Audit | `AdminActivity` + `AdminAudit` concern (admin-namespaced controllers only) | `app/models/admin_activity.rb` |
| Docs | One `phases/phase-NN-*.md` per phase + `README.md` tracker | `docs/IDENTITY_265 - Hire an Analysis - Assessment Session/phases/` |

## Blockers

None. Both working trees are clean on `main`; nothing to stash, reset, or preserve.

## Exit criteria

Workspace verified → proceed to Phase 1.