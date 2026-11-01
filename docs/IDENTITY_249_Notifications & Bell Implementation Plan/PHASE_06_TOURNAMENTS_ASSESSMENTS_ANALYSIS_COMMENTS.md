# Phase 6 — Tournaments, assessments, analysis, comments

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §8 (Phase 6)
**Status:** **Deferred** — audited, not implemented in this change.

## 1. Why deferred

The plan's own instruction for this phase is explicit:

> "Defer events for unimplemented features rather than adding speculative callbacks."
> "Do not create placeholder business entities."

The audit below shows that several of the plan's proposed events either have no corresponding
workflow in BVH today, or carry a privacy/recipient decision that needs a product owner's input
before code is written. Implementing them speculatively would risk exactly the leaks the plan warns
about (private assessment scores, broad fanout).

## 2. Audit of the proposed events

| Plan event | BVH counterpart found | Assessment | Decision |
|---|---|---|---|
| `tournament.registration_confirmed` | `TournamentParticipation` (created by a manager, not a public sign-up) | There is no self-service registration transition to hook | **Defer** — no matching workflow |
| `tournament.schedule_changed` | `TournamentsController#update` | Reachable, but "who is a registered participant" needs a product decision (divisions/participation vs. follows) | **Defer** |
| `tournament.cancelled` | `TournamentsController#cancel` | Reachable | **Defer** — recipient rule needs confirmation (this is the strongest Phase 6 candidate) |
| `assessment.shared` | `Assessment` publish/visibility | Reachable, but the payload must never contain scores | **Defer** — needs a privacy-reviewed message template |
| `analysis.requested` / `analysis.completed` | `Analysis` create/publish | Reachable | **Defer** — "assigned coach" vs "requester" rule needs confirmation |
| `comment.created` / `comment.replied` | `AnalysisComment` create | Reachable | **Defer** — needs loop/spam prevention design |
| `announcement.published` | *no entity exists* | Not implemented | **Not applicable** |

Account-claim events (`player_claim.approved`, `profile claim decision`) were also reviewed: BVH
already emails claim decisions (`ProfileClaimsMailer.decision` via `PlayerClaimService`), so an
in-app notification would need to be paired with that existing flow deliberately rather than bolted
on.

## 3. What would be required to complete this phase

1. A product decision per event on **who the recipients are** and **what text is safe**.
2. A privacy review for any assessment/analysis payload (the plan: "Do not put private assessment
   details in title/body/push/email").
3. Hooking the same `Notifications::Publisher` from the relevant controller/service after a
   committed transition — the infrastructure and patterns from Phases 3/5 are already in place, so
   each event is a small, additive change plus tests.

## 4. Exit criteria

| Criterion | Result |
|---|---|
| Existing entities/transitions verified before coding | ✅ audited (section 2) |
| No speculative callbacks added | ✅ |
| No placeholder business entities created | ✅ |
| Recipients resolved from real permissions | ⏳ pending product decision |
| Privacy-reviewed payloads | ⏳ pending privacy review |
