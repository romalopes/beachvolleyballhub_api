# Phase 9 — Follow subscriptions

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §11
**Status:** **Deferred** — not implemented in this change.

## 1. Why deferred

The plan is explicit that following is optional and must not be conflated with transactional
recipients:

> "Following is **not** organisation membership and is **not** needed for transactional events."
> "Add a polymorphic Follow feature **only after** auditing existing follow/member models."

The audit found that BVH **already has a follow model**, but it is domain-specific:

- `TournamentFollow` — `has_many :tournament_follows` on `Account` (see `app/models/account.rb`),
  used by the tournament "My tournaments" feature.

So the plan's proposed generic polymorphic `follows` table would **duplicate** an existing concept
for at least the tournament case, and the remaining followable candidates (Organisation, Group,
CoachProfile, TrainingSession, PlayerProfile) each need a privacy decision:

| Candidate | Concern |
|---|---|
| Organisation / Group | Could become a shadow of membership; needs a rule so followers never gain visibility they lack |
| CoachProfile / PlayerProfile | Privacy — the plan flags PlayerProfile as "only after explicit privacy design" |
| TrainingSession | Sessions are short-lived; following them has unclear value |

Adding a speculative generic follow table now would risk the "shadow membership" problem the plan
warns about, with no product requirement driving it.

## 2. What exists today instead

- Transactional notifications (training, membership) are delivered **without** any follow concept —
  recipients come from real participation/membership rows (Phase 5).
- The preference model (Phase 7) already supports **muting** event types, which covers the most
  common "I don't want this" need without a subscription system.
- `TournamentFollow` remains the existing, working follow mechanism for tournaments.

## 3. What would be required to complete this phase

1. Decide, per entity, whether following is allowed and what visibility it grants (must **not**
   grant access to private records).
2. Reuse `TournamentFollow` for tournaments rather than creating a parallel table; introduce a
   generic polymorphic `follows` table only if two or more new entities genuinely need it.
3. Feed optional followers into `Notifications::WorkflowEvents` as **additional** recipients,
   never replacing transactional ones.
4. Add follow/unfollow API + UI, with unique `(account_id, followable_type, followable_id)`.
5. Tests for visibility, duplicate follows, unfollow behaviour, and the "following ≠ membership" rule.

## 4. Exit criteria

| Criterion | Result |
|---|---|
| Existing follow/member models audited | ✅ (`TournamentFollow` found) |
| No duplicate follow table created | ✅ |
| Follow ≠ membership enforced | ✅ (no follow feature added) |
| Follow/unfollow API + UI | ⏳ pending product decision |
