# Phase 1 — Codebase Inspection & Architecture Report

**Status:** ✅ Complete (24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 1)

## Backend domain model (verified against source)

| Concern | File(s) | Findings |
|---------|---------|----------|
| AssessmentSession | `app/models/assessment_session.rb`, `db/schema.rb` (~L429) | `belongs_to :assessment_definition`, `:coach_profile`; optional `:created_by` (User), `:group`. `has_many :participants` (AssessmentSessionParticipant, dependent: destroy), `:assessments` (dependent: nullify), `:consolidation_sessions`, `:analysis_assessment_sessions → :analyses`. Lifecycle `STATUSES = draft/published/withdrawn` (string column, default `draft`), `published_at`. Drafts hard-delete their own draft results; published sessions are archival (admin-only destroy). |
| Participants | `app/models/assessment_session_participant.rb` | `belongs_to :assessment_session`, `:player_profile`; `INCLUSIONS = included/excluded`; uniqueness per session. "Involved players" map to participant rows. |
| Results | `app/models/assessment.rb` | `belongs_to :player_profile, :coach_profile`; optional `:assessment_session`, `:training_session`, `:assessment_definition`, `:discipline`; `has_many :assessment_category_scores`. |
| Services | `app/services/assessment_session_{creator,publisher,restorer,roster,score_grid,ranking}.rb` | Creation seeds a group roster; publish activates draft results; restore re-publishes withdrawn sessions. |
| Policy | `app/policies/assessment_session_policy.rb` | Only `link_to_analysis?` today (admin ‖ curator ‖ creator ‖ assigned coach via `record.coach_profile.account_id == account.id`). No `show?`/`update?`/`Scope` yet. |
| Controller | `app/controllers/api/v1/assessment_sessions_controller.rb` | `before_action :require_training_manager!` on EVERY action (incl. `index`/`show`). Subscription gate `advanced_assessments` on create/update/publish/restore. Actions: index, show, create, update, destroy, add_players, remove_players, scores, publish, withdraw, restore, ranking. Inline `serialize(s, detail:)`. |
| Routes | `config/routes.rb` L330 | `resources :assessment_sessions, only: %i[index show create update destroy]` + member routes (`add_players`, `remove_players`, `scores`, `publish`, `withdraw`, `restore`, `ranking`). ID-based. Analysis-link member routes at L398/L424 (`link_assessment_session`, `unlink_assessment_session`). |
| Organisations | `app/models/organisation_membership.rb`, `app/services/organisation_access.rb` | Membership keyed on Account with polymorphic `memberable` (Account/PlayerProfile/CoachProfile). `ROLES = owner/administrator/coach/member`; `STATUSES = pending/active/suspended/ended`; `active` scope. **AssessmentSession has NO organisation association** — mapping decision required (D3/Q1). |
| Roles | `app/models/user.rb` | `guest/player/coach/curator/admin`; `content_manager? = coach ‖ curator ‖ admin` — this is what `require_training_manager!` gates on. |
| Audit | `app/models/admin_activity.rb`, `app/controllers/concerns/admin_audit.rb` | `AdminActivity(user, action, entity_type, entity_id, entity_label, ip_address, user_agent)`, written by `after_action` in admin-namespaced controllers only. Assessment sessions are NOT admin-namespaced → Phase 10 needs a destination decision (Q5). |
| Token precedents | `app/models/weather_share_snapshot.rb`, `app/models/analysis_request.rb` | Weather: plaintext `public_token` = `SecureRandom.urlsafe_base64(24)`, expiry + `revoke!`, `public_url` from `FRONTEND_URL` env. AnalysisRequest: plaintext `guest_access_token` = `urlsafe_base64(32)`. **No digest-storage precedent exists** — the parent plan's SHA-256 digest rule is a deliberate deviation (D2). |
| Media | — | AssessmentSession has NO video/attachment surface. Videos belong to Analyses (`analysis_videos`/R2). Exposure risks are serializer fields (`notes`, account names), participants, scores/results, the `ranking` payload, and analysis-deliverable linkage. **Phase 6 scope narrows accordingly.** |

## Current read-authorization behavior (the delta this feature changes)

- `index`/`show` are gated only by `require_training_manager!`: any coach, curator or admin can read EVERY session; players and guests are refused outright. No per-record checks; the policy is not consulted.
- Therefore visibility introduces, each deliberately: (a) per-record filtering for managers, (b) first-ever player access (involved players under `internal`), (c) any-authenticated-user access (`public`), (d) unauthenticated token access (`unlisted`).

## Frontend (verified)

| Concern | File(s) | Findings |
|---------|---------|----------|
| Routes | `src/App.tsx` L479–497 | `/assessments`, `/assessment-sessions`, `/assessment-sessions/:id` — all wrapped in `ManagerRoute` (role ∈ coach/curator/admin, L130). |
| Pages | `src/pages/AssessmentSessions.tsx` (652 L), `src/pages/AssessmentSessionDetail.tsx` (441 L), `src/components/assessments/AssessmentSessionRoster.tsx` | List, detail, roster editing. |
| API client | `src/api.ts` (5668 L) | Central client; `TOKEN_KEY = "bvb_api_token"`; `Authorization: Bearer` when a token exists. Every assessment-session call is authenticated today — the share endpoint will need an unauthenticated fetch path. |
| Sharing precedent | `src/components/weather/WeatherShareDialog.tsx` | Copy-link + WhatsApp share dialog — model for Phase 8. |
| Types | `src/api.ts` `AssessmentSession` | Add `visibility`, `public_slug`; never expose `share_token_digest`. |

## Test surface (verified)

- API: `test/models/assessment_session_test.rb`, `test/models/assessment_session_participant_test.rb`, `test/controllers/api/v1/assessment_sessions_controller_test.rb` (Minitest + fixtures, `bin/rails test`).
- Frontend: co-located Vitest `*.test.tsx`; `npm run test`, `npm run lint`.

## Architecture deviations from the parent plan (carry into Phases 2–3)

1. **D1 — `visibility` as a string column, not an integer enum.** The repo uses string status columns + frozen constants (`STATUSES`, `VISIBILITIES` on `CoachProfile`), not Rails integer enums. Implement `VISIBILITIES = %w[public unlisted internal private]`, DB default `internal`, model inclusion validation + DB default + CHECK constraint. (Parent plan §4 explicitly defers to repo conventions.)
2. **D2 — digest-only token storage.** No precedent stores digests; the parent plan mandates it. Keep: SHA-256 of `SecureRandom.urlsafe_base64(24)`, raw token returned once.
3. **D3 — no organisation association on AssessmentSession.** "Organization members" cannot be resolved without a mapping decision (Q1 below).
4. **D4 — lifecycle interaction.** Sessions already have draft/published/withdrawn. Drafts are working notes and must never leak through public/unlisted. Recommended: visibility semantics apply to published sessions; drafts stay coach-of-record + oversight + admin regardless of visibility.

## Open product decisions (resolve before Phase 2 approval)

1. **Q1 — Organisation mapping.** How is "the organisation associated with the assessment" determined? (a) active organisations of the session's `coach_profile`; (b) drop the org dimension — internal = assigned coach + involved players; (c) other.
2. **Q2 — Private audience.** Coach of record + admin only, or also curators (today's oversight role)?
3. **Q3 — Involved players.** `inclusion: "included"` rows only, or any participant row?
4. **Q4 — Draft/withdrawn gating.** Confirm D4.
5. **Q5 — Audit destination.** Reuse/extend `AdminActivity` vs a dedicated visibility-event log (Phase 10).
6. **Q6 — Listing behavior for players.** May an involved player see the session in a personal list (scoped `index`), or detail-only access?

## Exit criteria

Owner reviews this report and the Phase 2 draft; Q1–Q6 resolved → approve contract → Phase 3 may start.