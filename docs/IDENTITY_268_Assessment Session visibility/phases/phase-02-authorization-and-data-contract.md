# Phase 2 — Authorization & Data Contract (DRAFT — awaiting owner approval)

**Status:** 🟡 Draft — DO NOT IMPLEMENT until the owner approves (parent plan §7 Phase 2 exit criteria)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md`

## 1. Definitions mapped to real records

| Term | Implementation |
|------|----------------|
| Coach of record / assigned coach | `assessment_session.coach_profile` — there is exactly one coach per session, so "assigned" and "authorized" coincide. Match: `coach_profile.account_id == Current.user.account.id`. |
| Involved player | `AssessmentSessionParticipant` row for the player's `player_profile`. Default: `inclusion: "included"` only (Q3). |
| Organization member | Q1 decision. Recommended (a): organisations where the session's `coach_profile` holds an `OrganisationMembership` with `status: "active"` and `memberable_type: "CoachProfile"`; their ACTIVE members qualify. |
| BVBH administrator | `User#admin?` via `ApplicationPolicy#admin?` (effective user; impersonation semantics inherited). |
| Curator | `User#curator?` — today's oversight role. Q2 decides private visibility. |

## 2. Permission matrix (DRAFT)

V = view, U = update, D = destroy, M = manage visibility, L = regenerate share link, P = manage participants/scores/publish lifecycle.

| Actor | Public | Unlisted (standard auth path) | Internal | Private |
|-------|--------|-------------------------------|----------|---------|
| Anonymous | — (frontend → login) | token-only path | — | — |
| Registered user, no relation | V | — | — | — |
| Player, uninvolved | V | — | — | — |
| Player, involved | V | — | V | — |
| Coach, unassigned | V | — | — | — |
| Coach of record | V U D M L P | V U D M L P | V U D M L P | V U D M L P |
| Curator | V | V (management per existing oversight rules) | V (+management) | Q2: V or — |
| Admin | V U D M L P | V U D M L P | V U D M L P | V U D M L P |
| Share-token holder (no login) | n/a | V read-only, restricted payload | n/a | n/a |

Notes:
- Unlisted does NOT make a session viewable to arbitrary authenticated users via the standard path (unlisted ≠ public). The coach of record retains management access because of management authorization, not because of visibility — this encodes parent plan Phase 4 rule 5.
- Draft sessions: coach of record + curator + admin only, regardless of `visibility` (D4). Withdrawn: as today, admin-only actions, read per visibility of a published peer (Q4 confirms).
## 3. Resource/field exposure matrix (DRAFT)

| Field / nested | Manager payload | Public/Unlisted restricted payload |
|----------------|-----------------|-------------------------------------|
| id, name, status, scheduled_on, definition (name/labels/weights) | ✓ | ✓ |
| public_slug, visibility | ✓ | ✓ (identifier + indicator) |
| notes | ✓ | ✗ (coach notes) |
| coach_profile.display_name | ✓ | ✓ (attribution) |
| coach account_name | ✓ | ✗ (Q7) |
| participants[].player_name | ✓ | ✓ (Q7: full display name vs first name) |
| participants[].account_name | ✓ | ✗ |
| participants[].inclusion / missing_reason | ✓ | included rows only; missing_reason ✗ |
| results (category scores) | ✓ | Q7: percent/aggregate only vs raw values |
| ranking block, consolidations | ✓ | ✗ (club-ranking context is internal) |
| emails, phones, DOB | not serialized today | must NOT appear — pin with tests |

No consent machinery exists in code; default to minimum exposure and let the owner finalize (Q7).

## 4. Policy interface (proposed)

Extend `AssessmentSessionPolicy` (reuse; do not duplicate logic in controllers or React):

- `show?` — matrix above; slug lookup path and ID path share it.
- `update?`, `destroy?`, `add_players?`, `remove_players?`, `scores?`, `publish?`, `withdraw?`, `restore?` — management set = coach of record (+ curator/admin per existing `oversight_or_coach_of_record?` semantics; published destroy stays admin-only as today).
- `manage_visibility?` — coach of record + admin (+ curator, matching oversight).
- `regenerate_share_link?` — same set AND record must be unlisted.
- `Scope#resolve` — managers: all sessions (current behavior); players: sessions where they are involved participants (internal/public only); others: public only (Q6).
## 5. API contract (DRAFT)

1. `GET /api/v1/assessment_sessions/:public_slug` — auth required; `show?` decides; 200 full-or-restricted payload; 404 unknown slug.
2. `GET /api/v1/assessment_sessions/share/:share_token` — NO auth; SHA-256 the supplied token and match `share_token_digest`; only when `visibility == "unlisted"`; restricted payload; otherwise 404 (no existence disclosure); `Cache-Control: private, no-store`.
3. `PATCH/PUT /api/v1/assessment_sessions/:id` (existing) — accepts `visibility` in strong params for authorized users; unknown value 422; leaving unlisted clears the digest in the same transaction.
4. `POST /api/v1/assessment_sessions/:public_slug/regenerate_share_link` — authorized management only; requires unlisted; new token, digest replaced atomically; returns `{ "share_url": ... }` once; 200.
5. Existing ID-based routes remain during the compatibility period; the frontend migrates to slug routes in Phase 9.

Share URL: `#{FRONTEND_URL}/assessments/share/#{raw_token}` (mirrors `WeatherShareSnapshot#frontend_url`).

Response additions: `visibility`, `public_slug` in payloads; raw token ONLY in the generation response; digest never serialized.

## 6. Status codes

As parent plan §6.5. Generation returns 200 with `{ share_url }` (repo returns `:created` only for resource creation).

## 7. Visibility transition behavior

- unlisted → any other: digest cleared atomically; old token dead immediately.
- x → unlisted: no token until generation is explicitly requested (plan §6.4 default flow).
- Every change: audit event (Phase 10, destination per Q5).

## 8. Unresolved questions blocking Phase 3

| # | Question | Recommended default |
|---|----------|---------------------|
| Q1 | Organisation mapping for internal | (a) coach of record's active CoachProfile memberships |
| Q2 | Curator may view private | Yes (oversight parity) |
| Q3 | Involved player definition | `included` rows only |
| Q4 | Draft/withdrawn gating | Drafts: coach + oversight + admin only, regardless of visibility |
| Q5 | Audit destination | Extend `AdminActivity` usage via a service-layer event writer |
| Q6 | Player listing | Involved players get detail access + a scoped personal list |
| Q7 | Public/unlisted person exposure | Display names + scores; no account names, notes, ranking context |

## 9. Test plan preview (Phases 3–5)

- Model: visibility validation/default; slug uniqueness/stability; digest-only storage; regeneration invalidation; clearing on transition; collision retry.
- Policy: the full matrix incl. anonymous, removed membership/assignment, view-vs-manage separation.
- Requests: token flow (valid/invalid/revoked/post-transition), slug flow, auth gates, token absent from show/index and logs, public/unlisted payload shaping.
- Viewing never grants U/D/M/L/P.