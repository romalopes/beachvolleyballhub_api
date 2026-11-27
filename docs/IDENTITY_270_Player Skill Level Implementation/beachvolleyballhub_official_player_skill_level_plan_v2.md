# BeachVolleyballHub --- Official Player Skill Level

## Detailed implementation plan and AI prompts

**Primary issue:** [API issue
#270](https://github.com/romalopes/beachvolleyballhub_api/issues/270)\
**Repositories:**
[API](https://github.com/romalopes/beachvolleyballhub_api) ·
[Frontend](https://github.com/romalopes/beachvolleyballhub_frontend)

## Phase documentation

Each implementation phase has a dedicated document in `phases/`:

| Phase | Title | Document | Status |
|-------|-------|----------|--------|
| 00 | Repository & issue audit (no code changes) | [`phases/phase-00-repository-and-issue-audit.md`](phases/phase-00-repository-and-issue-audit.md) | ⏳ Not started |
| 01 | Configurable classification | [`phases/phase-01-configurable-classification.md`](phases/phase-01-configurable-classification.md) | ⏳ Not started |
| 02 | Calculation policy & source selection | [`phases/phase-02-calculation-policy-and-source-selection.md`](phases/phase-02-calculation-policy-and-source-selection.md) | ⏳ Not started |
| 03 | Curator/Admin authorization | [`phases/phase-03-curator-admin-authorization.md`](phases/phase-03-curator-admin-authorization.md) | ⏳ Not started |
| 04 | Source adapters & calculation engine | [`phases/phase-04-source-adapters-and-calculation-engine.md`](phases/phase-04-source-adapters-and-calculation-engine.md) | ⏳ Not started |
| 05 | Identity assignment & history | [`phases/phase-05-identity-assignment-and-history.md`](phases/phase-05-identity-assignment-and-history.md) | ⏳ Not started |
| 06 | Curator/Admin administration workflow | [`phases/phase-06-curator-admin-administration-workflow.md`](phases/phase-06-curator-admin-administration-workflow.md) | ⏳ Not started |
| 07 | Player profile & search integration | [`phases/phase-07-player-profile-and-search-integration.md`](phases/phase-07-player-profile-and-search-integration.md) | ⏳ Not started |
| 08 | Backfill, reconciliation & release | [`phases/phase-08-backfill-reconciliation-and-release.md`](phases/phase-08-backfill-reconciliation-and-release.md) | ⏳ Not started |
| 09 | Final security & regression review | [`phases/phase-09-final-security-and-regression-review.md`](phases/phase-09-final-security-and-regression-review.md) | ⏳ Not started |

Phase index: [`phases/README.md`](phases/README.md)

---

## 1. Objective and principles

Implement an official calculated Player Skill Level as part of the
canonical player identity.

Requirements: - Only **Curators and Admins** can manage the official
calculation policy, preview calculations, initiate/re-run calculations,
and inspect administrative reports. - BVBH explicitly selects the
authoritative source. - Support either one selected **Assessment
Session** or one selected **Ranking Consolidation**. - Reuse existing
assessment scoring and consolidation logic. Do not build a second
scoring or averaging engine. - Store the current official level and
retain immutable/auditable assignment history. - Expose the current
level through player identity/profile APIs and future player search. -
Keep the official skill level separate from tournament division and the
existing coach-entered `PlayerProfile.level`.

**Core principle:** BVBH controls the source and policy; an authorised
Curator or Admin initiates the operation; the system calculates the
level; the player's identity retains the official result and its
provenance.

Publishing an Assessment Session must not automatically change official
player levels. Do not automatically select the latest published session.

## 2. Classification

Initial proposed classification. BVBH must approve the thresholds; they
remain configurable, not hardcoded.

Code Description Minimum Maximum

---

B Beginner 0 19
BB Developing 20 34
BBB Intermediate 35 49
A Advanced 50 64
AA Competitive 65 79
AAA High Performance 80 89
AAAA Elite 90 100

| Minimum score | Maximum score | Code | Description      |
| ------------: | ------------: | ---- | ---------------- |
|             0 |            19 | B    | Beginner         |
|            20 |            34 | BB   | Developing       |
|            35 |            49 | BBB  | Intermediate     |
|            50 |            64 | A    | Advanced         |
|            65 |            79 | AA   | Competitive      |
|            80 |            89 | AAA  | High Performance |
|            90 |           100 | AAAA | Elite            |

Validation must ensure bounds are within 0--100, minimum does not exceed
maximum, ranges do not overlap, every integer score maps to exactly one
active level, codes are unique, and ordering is deterministic.

These labels may resemble tournament divisions, but they are different
concepts. An official skill level must not automatically set, restrict
or override tournament registration division.

## 3. Permissions

Action Admin Curator Coach Player

---

View official level Yes\* Yes\* Yes\* Yes\*
Configure/activate policy Yes Yes No No
Select source Yes Yes No No
Preview calculation Yes Yes No No
Initiate/re-run calculation Yes Yes No No
View full administrative audit Yes Yes No No
Edit official level directly No No No No

`*` Viewing follows existing player/profile visibility rules.

Enforce permissions in Rails API policies/controllers/services, not only
by hiding React controls. Derive the operator from the authenticated
user. Never trust a client-supplied operator ID, score, level code or
assignment.

Coaches may continue normal Assessment Session workflows, but
publication must not trigger official level recalculation.

## 4. Calculation source and policy

Create or reuse a BVBH-controlled policy that identifies: - Source type:
`assessment_session` or `ranking_consolidation`. - The specifically
selected source record. - Compatible Assessment Definition/version where
applicable. - Classification version. - Active status. -
Configuring/activating user and timestamps. - Optional reason/notes.

A policy change must not silently rewrite historical results. Each
calculation must preserve the exact policy and classification version
used.

### Option A --- One Assessment Session

Use the selected eligible session's existing complete
`PlayerAssessment.overall_score` for each player. Validate session
lifecycle, publication status, definition/version compatibility and
score validity. Missing or incomplete player rows are skipped and
reported; they are never converted to zero. Do not silently substitute
another session.

### Option B --- Ranking Consolidation

Use the selected `RankingConsolidation` and its existing
`RankingConsolidationResult` score. Before implementation, inspect the
actual consolidation contract: - Is the result an average of 0--100
`overall_score` values, a weighted score, a rank/position, or something
else? - How are missing/incomplete results treated? - Are sessions
equally weighted? - Can the consolidation mix definitions or versions? -
Is the result finalized/immutable?

Only a comparable numeric score on the approved scale can be mapped to
the proposed classification. A rank/position must not be treated as a
percentage. If the existing consolidation does not provide a compatible
score, stop and request a product/technical decision. Do not invent a
conversion or second averaging engine.

### No automatic selection or publication trigger

The BVBH team chooses the source. A Curator/Admin reviews and initiates
the calculation. Creating/changing a policy or publishing/updating an
assessment does not itself change official levels.

## 5. Recommended architecture

Separate these responsibilities; reuse equivalent existing models if the
repository already has them.

### 5.1 PlayerLevel

Configurable catalogue: - `code`, `name` - `minimum_score`,
`maximum_score` - `position`, `active` - timestamps and classification
version/effective date if needed

### 5.2 PlayerSkillLevelPolicy

Stores source type/reference, compatible definition/version or
consolidation configuration, classification version, active status and
audit metadata. Enforce exactly one source reference matching the source
type.

Start with one global BVBH policy unless the audit identifies a real
need for multiple scopes.

### 5.3 Source adapters

Implement two adapters behind one interface: - Assessment Session
adapter. - Ranking Consolidation adapter.

Both return a common result containing canonical player reference,
normalized score, source type and source ID. They must read existing
domain results rather than duplicate score calculation.

### 5.4 PlayerSkillLevelCalculation

One authorised calculation run: - source and policy
references/snapshots; - initiating Curator/Admin; - status (pending,
processing, completed, completed with errors, failed); -
started/completed timestamps; - processed/skipped/failed counts; -
report/error details; - idempotency/request key where consistent with
project conventions.

### 5.5 PlayerSkillLevelAssignment

Historical assignment: - canonical player identity reference; -
PlayerLevel reference and useful code/name snapshot; - score used; -
calculation reference; - source type/source ID; - policy/classification
version; - effective/calculated timestamp.

Expose a current official assignment through the canonical identity,
while retaining previous assignments. Update the current
pointer/association transactionally.

**Identity ownership must be established by repository audit.** Do not
assume `Person` or `PlayerProfile` is canonical. Do not duplicate
independently editable official levels across records. Preserve
`PlayerProfile.level`.

## 6. Implementation phases

### Phase 0 --- Repository and issue audit (no code changes)

Inspect both repositories and issue #270.

API: - `Person`, `PlayerProfile`, account/identity associations. -
`AssessmentDefinition`, categories, version/freeze behavior. -
`AssessmentSession` lifecycle/publication timestamp. -
`PlayerAssessment` completeness and `overall_score`. - Assessment
scoring services. - `RankingConsolidation`,
`RankingConsolidationResult`, consolidation services. - Curator/Admin
authorization and role permissions. - Audit/history and background-job
conventions. - Profile controllers, serializers, routes and search
endpoints.

Frontend: - Admin navigation and role access. - Assessment Session and
Ranking Consolidation screens. - Player profile/identity components. -
Player search filters. - API client/types and tests.

Answer explicitly: 1. What is the canonical player identity? 2. What
exact metric does consolidation expose? 3. Is it a normalized score or
rank/position? 4. How are missing/incomplete results handled? 5. Can
consolidations mix definitions/versions? 6. Which lifecycle states are
eligible? 7. How are Curator/Admin permissions enforced? 8. What
audit/history patterns exist? 9. Which search endpoint should expose
current level?

**Deliverables:** exact file map; existing behavior/contracts; proposed
data model/API; risks and migration plan; test plan. Do not code until
score semantics are clear.

### Phase 1 --- Configurable classification

- Confirm descriptions and thresholds with BVBH.
- Reuse an existing suitable level model or create the smallest
  appropriate model.
- Add constraints, validations and idempotent provisioning.
- Add one shared score-to-level resolver.
- Preserve classification versions/snapshots so historical assignments
  remain interpretable.
- Restrict changes to Curator/Admin.

Tests: every integer 0--100 maps exactly once; boundary values;
gaps/overlaps; duplicate codes; inactive levels; idempotent seeds;
historical version retention.

### Phase 2 --- Calculation policy and source selection

- Implement/reuse policy model and API.
- Support both source types.
- Validate source-specific references and prevent conflicting IDs.
- Validate source lifecycle and score compatibility.
- Bind to compatible definition/version or consolidation
  configuration.
- Record policy creator/activator and timestamps.
- Do not calculate when policy is merely created or changed.
- Preserve policy versions/snapshots.

Tests: valid policies; missing/wrong source; both source IDs; ineligible
source; incompatible definition/version; policy changes do not mutate
old assignments; role authorization.

### Phase 3 --- Curator/Admin authorization

- Reuse existing role/permission framework.
- Protect policy management, preview, calculation, rerun and audit
  endpoints.
- Ensure background jobs can only execute persisted, authorised
  calculation requests.
- Prevent client mass-assignment of official score/level/source
  fields.
- Ensure session publication cannot trigger official calculation.

Tests: Admin and Curator allowed; Coach/player denied; direct API
denial; forged operator/job request denied; existing assessment
permissions unchanged.

### Phase 4 --- Source adapters and calculation engine

- Define a common source-result interface.
- Implement Assessment Session adapter reading complete
  `overall_score`.
- Implement Ranking Consolidation adapter reading the existing
  compatible result.
- Use one shared classification resolver.
- Implement one calculation orchestrator that revalidates
  policy/source at execution, gets eligible scores, resolves levels,
  records skips/failures, creates assignments and updates current
  identity.
- Make execution auditable, idempotent, transactional where
  appropriate, retryable and concurrency-safe.
- Prevent stale jobs from overwriting newer assignments.

Tests: both source types; boundaries; missing/incomplete player; invalid
score; ineligible/empty source; duplicate initiation; rollback;
concurrency; stale job; partial failure/retry; regressions.

### Phase 5 --- Identity assignment and history

- Attach current official level to the canonical identity identified
  in Phase 0.
- Retain historical assignments.
- Record score, source, policy/classification version, calculation,
  operator and timestamp.
- Represent no assignment as null/unassessed.
- Update current assignment transactionally.
- Keep coach-entered `PlayerProfile.level` and tournament division
  untouched.
- Prevent client writes.

Tests: current result; append-only history; provenance; unassessed
state; forged writes rejected; identity association correct; legacy
fields unchanged.

### Phase 6 --- Curator/Admin administration workflow

Recommended flow: 1. Select source type. 2. Select specific Assessment
Session or Ranking Consolidation. 3. Review status, definition/version
and compatibility. 4. Preview eligible players, skipped players and
reasons. 5. Preview score-to-level results and level distribution. 6.
Review warnings. 7. Explicitly confirm. 8. Initiate one calculation. 9.
Review progress, processed/skipped/failed counts and details. 10.
Inspect calculation history.

Build role-protected screens, source selectors, preview API/UI,
confirmation, status/report and history. Revalidate authorization and
source on the server at confirmation/execution. Prevent duplicate
clicks/submissions.

Tests: navigation/access; API authorization; source validation;
preview/execution consistency; duplicate submission; partial failure
reporting.

### Phase 7 --- Player profile and search integration

Profile: - Display official code/name. - Display score/date where
permitted. - Display source type/details only where viewer has access. -
Show unassessed when no current assignment exists. - Keep coach-entered
level/notes separate. - Keep tournament division separate.

Search: - Add filters for current official level. - Support one/multiple
codes if consistent with existing filter patterns. - Search current
assignments only, not history. - Add indexes based on actual query
plans. - Respect privacy and visibility.

Expose a stable API contract for future partner search, training groups,
recommendations and analytics. Do not implement those future features in
this project.

Tests: profile display; unassessed; single/multiple filters; history not
causing false matches; tournament division independence; visibility;
query performance.

### Phase 8 --- Backfill, reconciliation and release

- Do not infer source from latest date or display name.
- Require an explicitly approved policy/source.
- Provide dry-run preview with player, source, score, proposed level
  and skip reason.
- Require authorised confirmation before applying historical
  assignments.
- Make backfill idempotent and auditable.
- Do not modify `PlayerProfile.level` or tournament division.
- Test migrations/jobs/permissions/profile/search in staging.
- Document deployment, monitoring, retry and rollback.

Possible task names (adapt to project conventions):

```bash
bin/rails player_skill_levels:preview
bin/rails player_skill_levels:recalculate
```

### Phase 9 --- Final security and regression review

Verify: - Curator/Admin-only management and initiation. - Explicit BVBH
source selection. - Both source adapters use existing logic. -
Consolidation metric is genuinely compatible. - No implicit
latest-session selection. - No publication-triggered recalculation. -
Configurable classification and historical versions. - Correct canonical
identity ownership. - Complete provenance and immutable history. - API
cannot forge level/operator. - Duplicate/concurrent/stale operations
safe. - Profile/search use current assignment. - Coach-entered level and
tournament division unchanged. - Privacy/visibility respected.

Run backend/frontend tests, lint, type checks, migrations and production
builds. Report only checks actually executed.

## 7. Suggested API contract

Adapt paths and payloads to existing API conventions; these are
conceptual operations: - Read/create/update/activate policy. - Preview
selected source. - Initiate calculation. - Read calculation
status/report. - List calculation history. - Read current official level
on identity/profile. - Filter player search by official level.

Server requirements: - Authenticated operator is derived from
session/token. - Client cannot submit authoritative
score/level/operator. - Preview and execution revalidate source
eligibility. - Execution records exact source and policy/classification
versions. - Repeated requests are idempotent or explicitly rejected.

## 8. AI prompts --- execute sequentially

Run each prompt in the relevant checked-out repository/workspace. Review
its output and tests before moving to the next. The coding agent must
inspect actual code and must not invent files, fields, endpoints or test
results.

### Prompt 1 --- Full repository and issue audit (no code changes)

```text
Reanalyse GitHub issue #270 and audit the current BeachVolleyballHub
API and frontend repositories for Official Player Skill Level.

Requirements:
- Only Curator and Admin may manage or initiate official calculations.
- BVBH explicitly selects the authoritative source.
- Source is one Assessment Session or one Ranking Consolidation.
- Reuse existing assessment scoring and consolidation logic.
- Official level becomes part of canonical player identity.
- Current level and historical assignments are retained.
- Level is available to future player search/filtering.
- Existing PlayerProfile.level and tournament division remain separate.

Inspect actual models, migrations, services, jobs, controllers, policies,
serializers, routes, frontend components, API types and tests.

Establish:
1. Canonical player identity record.
2. AssessmentSession lifecycle and publication eligibility.
3. PlayerAssessment completeness and overall_score semantics.
4. Exact RankingConsolidationResult metric and scale.
5. Whether consolidation is average, weighted score, rank or position.
6. Handling of incomplete results and mixed definitions/versions.
7. Curator/Admin authorization implementation.
8. Audit/history and background job conventions.
9. Existing player search endpoint/query strategy.

Do not change code.

Deliver exact file map, current contracts, reusable services, data model
recommendation, API/frontend change list, risks and tests. Do not assume
documentation matches code. Do not claim tests were run.
```

### Prompt 2 --- Configurable classification

```text
Implement configurable Player Skill Level classification based on the
repository audit.

Proposed initial levels, pending BVBH approval:
B 0-19 Beginner
BB 20-34 Developing
BBB 35-49 Intermediate
A 50-64 Advanced
AA 65-79 Competitive
AAA 80-89 High Performance
AAAA 90-100 Elite

Requirements:
- Reuse a suitable existing model or create the smallest appropriate one.
- Store code, name, minimum_score, maximum_score, position and active.
- Validate bounds, uniqueness, no overlap and complete 0-100 coverage.
- Add idempotent provisioning.
- Preserve classification versions/snapshots for historical interpretation.
- Add one shared score-to-level resolver.
- Do not hardcode boundaries in service logic.
- Restrict administrative changes to Curator/Admin.

Add migrations, constraints, tests and documentation. Do not modify
assessment scoring or tournament division logic.
```

### Prompt 3 --- BVBH policy and source selection

```text
Implement the BVBH-controlled Player Skill Level Calculation Policy.

Support source types assessment_session and ranking_consolidation.
The policy identifies the selected source record and applicable
assessment definition/version or consolidation configuration, plus
the classification version.

Validate source-specific references, lifecycle and score compatibility.
Do not automatically choose the latest session. Do not calculate merely
because a policy is created/changed. Preserve policy versions used by
previous calculations. Record who configured/activated it and when.
Restrict policy management to Curator/Admin.

Use the exact consolidation score contract found in the audit. If it is
rank/position or otherwise incompatible with the classification, stop
and report the required decision. Do not invent a conversion or second
averaging engine.

Add migrations, API endpoints, validations and tests.
```

### Prompt 4 --- Backend permissions

```text
Implement backend authorization for official Player Skill Level
administration and calculation.

Only Admin and Curator may manage/activate policy, select source,
preview, initiate/rerun calculations and view full administrative
reports/history.

Coaches may continue normal assessment workflows but cannot initiate
official calculations. Assessment Session publication must not update
official player levels.

Use existing authorization framework. Enforce permissions in Rails,
not only frontend navigation. Derive operator from authenticated user.
Prevent client writes to official level/score/source/assignment fields.
Ensure jobs execute only persisted, authorized calculation requests.
Preserve existing assessment permissions.

Add positive and negative tests for every operation and role.
```

### Prompt 5 --- Source adapters and calculation engine

```text
Implement the official Player Skill Level calculation engine.

Use one orchestrator and two source adapters:
1. Assessment Session: read complete existing PlayerAssessment.overall_score.
2. Ranking Consolidation: read existing RankingConsolidationResult metric.

Reuse existing scoring and consolidation logic. Do not implement a
second average. Only map consolidation results if they are a compatible
normalized score on the approved scale. If rank/position or incompatible,
stop and report.

Both adapters return canonical player reference, score, source type
and source ID.

The orchestrator loads/revalidates policy and source, resolves levels
through the shared classification, records skipped/failed players,
creates assignment history and updates current identity safely.

Make it transactional where appropriate, idempotent, retryable,
observable and concurrency-safe. Prevent stale jobs overwriting newer
assignments. Do not automatically select a source or trigger from
session publication.

Add tests for both sources, boundaries, missing data, invalid sources,
retries, duplicate requests and concurrency.
```

### Prompt 6 --- Identity and assignment history

```text
Implement official Player Skill Level persistence on the canonical
player identity identified in the audit.

Store current official PlayerLevel and retain historical assignments.
Each assignment records score, source type/source ID, calculation,
policy/classification version, operator and timestamp.

Requirements:
- Preserve source provenance.
- Represent no assignment as null/unassessed.
- Update current assignment transactionally.
- Do not overwrite PlayerProfile.level.
- Do not change tournament division.
- Prevent client-side writes to official fields.
- Avoid duplicate independently editable copies of official level.

Use existing identity and audit patterns. Add migrations, constraints,
associations, serializers and tests. Explain deviations from the plan.
```

### Prompt 7 --- Curator/Admin workflow

```text
Implement the administration workflow for official Player Skill Level.
Only Curator and Admin can access it.

Flow:
1. Select source type.
2. Select specific Assessment Session or Ranking Consolidation.
3. Review source status, definition/version and compatibility.
4. Preview eligible players, skipped players, scores and proposed levels.
5. Show level distribution and warnings.
6. Require explicit confirmation.
7. Initiate one calculation.
8. Show processing status and processed/skipped/failed counts.
9. Provide calculation history and detail.

Follow existing frontend/API conventions. Revalidate authorization,
policy and source on the server. Prevent duplicate submissions.
Never accept client-calculated scores/levels as authoritative.
Explain skipped players and failures.

Add frontend and backend tests.
```

### Prompt 8 --- Profile and search integration

```text
Integrate official Player Skill Level into player identity/profile
and player search.

Profile:
- Display official code and description.
- Display score/date where permitted.
- Display source details only where viewer has access.
- Show unassessed when no current assignment exists.
- Keep PlayerProfile.level separate.
- Keep tournament division separate.

Search:
- Filter by current official skill level.
- Support multiple codes if consistent with existing filters.
- Search current assignments only, not historical assignments.
- Add indexes based on actual query patterns.
- Respect privacy and visibility.

Expose stable API data for future partner search, training groups,
recommendations and analytics. Do not implement those future features.

Add backend/frontend tests for display, filtering and regressions.
```

### Prompt 9 --- Backfill and release

```text
Prepare safe backfill, reconciliation and release.

Do not infer official source from latest date or display name. Require
an explicitly approved BVBH policy/source. Provide dry-run preview with
player, source, score, proposed level and skipped reason. Require
authorized confirmation before applying historical assignments.
Make backfill idempotent and auditable.

Do not modify PlayerProfile.level or tournament division. Verify data
and report records that cannot be classified. Test migrations, jobs,
permissions, profile and search in staging. Document deployment,
monitoring, retry and rollback.

Run relevant tests, lint, type checks, migrations and production builds.
Report exact commands and actual results. Do not claim unexecuted checks.
```

### Prompt 10 --- Final review

```text
Perform a complete security, architecture and regression review.

Verify:
- Only Curator/Admin can manage or initiate calculations.
- BVBH explicitly controls source through policy.
- Both source types work and reuse existing logic.
- Consolidation score is compatible with classification.
- No automatic latest-session selection remains.
- Publication does not automatically change official level.
- Classification is configurable and historical versions retained.
- Current level belongs to canonical identity.
- History and provenance are preserved.
- API cannot forge official levels or operator identity.
- Duplicate/concurrent/stale operations are safe.
- Profile/search use current assignment.
- PlayerProfile.level and tournament division are unchanged.
- Privacy/visibility are respected.

Run relevant backend/frontend checks. Report changed files, migrations,
API contract, permission matrix, tests actually run, unresolved risks,
deployment and rollback. Do not make unrelated refactors or claim
unexecuted checks passed.
```

## 9. Acceptance criteria

1.  Only Curator/Admin can manage or initiate official calculations.
2.  BVBH explicitly selects the authoritative source.
3.  Both selected Assessment Session and selected Ranking Consolidation
    are supported.
4.  Existing scoring and consolidation logic is reused.
5.  Consolidation metric is proven compatible before classification.
6.  Levels/ranges are configurable.
7.  Every calculation records source, score, policy/classification
    version, operator and timestamp.
8.  Current official level is part of canonical player identity.
9.  Historical assignments remain available.
10. Publishing an Assessment Session does not automatically change
    official level.
11. Missing/incomplete scores are not converted to zero.
12. `PlayerProfile.level` remains unchanged.
13. Tournament division remains independent.
14. Profile and search use the current official assignment.
15. API permissions and privacy rules are enforced.
16. Backfill is controlled, auditable and idempotent.

## 10. Decisions to confirm before implementation

1.  Approve or adjust the proposed B--AAAA numeric ranges.
2.  Confirm the actual Ranking Consolidation metric is a suitable 0--100
    score (first a technical audit question).
3.  Start with one global BVBH policy unless multiple scopes are
    demonstrably required.
4.  Recommended: calculate all eligible players in the selected source;
    skip and report missing/incomplete players.
5.  Recommended: each recalculation creates a new immutable calculation
    and assignment history record.
6.  Apply existing profile visibility rules to the official level.

## 11. Recommended implementation order

1.  Phase 0 audit and confirm consolidation score semantics.
2.  BVBH approval of thresholds and policy scope.
3.  Classification and policy.
4.  Backend authorization.
5.  Source adapters and calculation engine.
6.  Identity assignment/history.
7.  Curator/Admin workflow.
8.  Profile and search.
9.  Backfill and release.
10. Final security/regression review.

**Do not start by adding a calculated-level column to `PlayerProfile`.**
First establish the canonical identity owner, source score contracts,
policy versioning and authorization boundaries. These decisions
determine the correct data model and avoid a fragile implementation.
