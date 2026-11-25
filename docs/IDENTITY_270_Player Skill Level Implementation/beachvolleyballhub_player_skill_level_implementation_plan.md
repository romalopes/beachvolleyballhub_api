# BeachVolleyballHub — Calculated Player Skill Level

## Detailed implementation plan and AI prompts

**Status:** Proposed specification  
**Scope:** BeachVolleyballHub API (Rails) and frontend (React/Vite)  
**Repositories:**
- API: <https://github.com/romalopes/beachvolleyballhub_api>
- Frontend: <https://github.com/romalopes/beachvolleyballhub_frontend>

---

## 1. Objective

Implement a calculated general Player Skill Level for each player in BeachVolleyballHub. The level is derived from the player's latest eligible, published **Player Skill Assessment** Assessment Session.

The feature must reuse the existing Assessment Definition, Assessment Session, Player Assessment and scoring workflow. It must not introduce a second assessment engine or independently recalculate the weighted assessment score.

The calculated level is separate from the existing `PlayerProfile.level` field. That existing field remains available for the coach's free-text level or notes and must not be overwritten.

## 2. Confirmed design decisions

| Area | Decision |
|---|---|
| Assessment source | Latest qualifying published Assessment Session |
| Assessment definition | A dedicated Player Skill Assessment definition |
| Score source | Existing `PlayerAssessment.overall_score` |
| Calculated level storage | Separate from `PlayerProfile.level` |
| Assessment workflow | Reuse the existing Assessment Session workflow |
| Level labels | B, BB, BBB, A, AA, AAA, AAAA |
| No eligible assessment | Unassessed; do not assign Beginner by default |

### 2.1 Skill level versus tournament division

The calculated Player Skill Level and a tournament registration division are different concepts, even though they use the same labels.

- **Calculated Player Skill Level:** a general technical/tactical level derived from the dedicated assessment.
- **Tournament Division:** the division selected or assigned for a particular tournament.

Do not automatically set, restrict or overwrite tournament registration divisions based on the calculated skill level. A player assessed as AA may register for a tournament in another division, subject to the tournament's own rules.

## 3. Proposed classification ranges

The following ranges are the initial proposal. They are not official equivalences to tournament divisions. Store the ranges as configurable records rather than hardcoding them in application logic.

| Minimum score | Maximum score | Code | Description |
|---:|---:|---|---|
| 0 | 19 | B | Beginner |
| 20 | 34 | BB | Developing |
| 35 | 49 | BBB | Intermediate |
| 50 | 64 | A | Advanced |
| 65 | 79 | AA | Competitive |
| 80 | 89 | AAA | High Performance |
| 90 | 100 | AAAA | Elite |

Requirements:

- Scores are integer values from 0 through 100, consistent with the existing assessment score contract. Confirm the actual score type and precision during the repository audit.
- Minimum and maximum values are inclusive.
- Active levels must cover the entire valid score range without gaps or overlaps.
- Each level has a unique code and a stable ordering position.
- Administrators may change the classification ranges through an authorized administration interface.
- If score precision is not integer-based in the current application, define and test the boundary behavior explicitly rather than silently rounding differently from the existing assessment workflow.

## 4. Dedicated Player Skill Assessment definition

Create or designate one Assessment Definition specifically for calculating general player skill level.

### 4.1 Stable identification

Identify the definition using a stable machine-readable purpose/key, for example:

`player_skill_level`

Do not identify it by its mutable display name alone. Inspect the existing Assessment Definition schema first. Reuse an equivalent field if it already exists. If not, consider adding a nullable unique `system_key` (or an equivalent field) so ordinary assessment definitions can continue to have no system key.

Provisioning must be idempotent: running seeds or the provisioning task repeatedly must not create duplicate definitions or categories.

### 4.2 Initial categories and weights

| Category | Weight |
|---|---:|
| Serving | 15% |
| Passing | 20% |
| Setting | 15% |
| Attacking | 20% |
| Defense and Blocking | 20% |
| Tactical Understanding | 10% |
| **Total** | **100%** |

Use existing category records and scoring controls wherever possible. Confirm the category model's current naming and reuse matching categories if appropriate; do not create near-duplicates unnecessarily.

### 4.3 Definition lifecycle and versioning

Respect the existing definition freeze/versioning rules:

- Once a definition has been used by sessions, do not mutate its historical scoring configuration in a way that changes the meaning of previous results.
- If category definitions or weights need to change after use, create a new version using the existing versioning pattern.
- Keep historical sessions linked to the exact definition/version used at the time.
- If the application needs to designate which version is currently used for future skill-level calculations, implement that designation explicitly and auditably. Do not infer the current version from a display name or the most recently created record without a deliberate rule.

## 5. Assessment selection and calculation rules

### 5.1 Eligible assessment requirements

A candidate result is eligible only when all the following are true:

1. Its Assessment Session uses the designated Player Skill Assessment definition/version.
2. The session has been published successfully.
3. The session has not been withdrawn, retracted or otherwise made ineligible under the actual application lifecycle.
4. The player has a corresponding PlayerAssessment row in that session.
5. That row is complete according to the existing application rules.
6. The row has a valid `overall_score` within the supported score range.

Do not treat a missing or incomplete assessment as zero. A player with an incomplete row in a newer session retains their latest previous valid calculated result.

### 5.2 What “latest” means

Use the actual publication timestamp, ordered descending, with a stable ID tie-breaker. Do not use `session_date`, `created_at` or an assumed timestamp as a substitute for publication order.

For example, if a session with an earlier session date is published after another session, it becomes the latest result under this rule.

During the repository audit, verify that a reliable publication timestamp exists. If not, add one through the existing lifecycle mechanism and backfill only where the historical publication time can be established reliably. Do not invent publication timestamps from session dates.

### 5.3 Fallback and clearing behavior

- If the newest published session has no complete result for the player, continue searching for the newest earlier eligible complete result.
- If a previously eligible session becomes ineligible, recalculate and fall back to the next latest eligible result.
- If no eligible result remains, clear the calculated score, level and source references and expose an **Unassessed** state.
- Archiving must be handled according to the real lifecycle contract discovered in the code. Do not assume that archived means either eligible or ineligible without confirming the intended semantics.

### 5.4 Score calculation

Use `PlayerAssessment.overall_score` as the canonical score. The existing assessment workflow owns category scoring and weighted aggregation. The new feature only maps that score to a configured PlayerLevel.

Do not calculate category weights again in the Player Level service.

## 6. Data model and API design

The following is a proposed design, subject to reuse of equivalent existing models/fields found during the audit.

### 6.1 PlayerLevel configuration

A `PlayerLevel` model/table may contain:

| Field | Purpose |
|---|---|
| `code` | B, BB, BBB, A, AA, AAA or AAAA |
| `name` | Beginner, Developing, etc. |
| `minimum_score` | Inclusive lower bound |
| `maximum_score` | Inclusive upper bound |
| `position` | Display ordering |
| `active` | Whether this level is available for classification |
| timestamps | Standard record timestamps |

Add database constraints and model validations for unique codes, valid ranges and ordering. Enforce the complete non-overlapping 0–100 range at the appropriate configuration/service level; a database constraint alone may not be sufficient to validate the relationship across multiple rows.

### 6.2 Calculated profile fields

Add separate calculated fields to `PlayerProfile`, or use an equivalent existing projection model if the repository already has one:

| Suggested field | Purpose |
|---|---|
| `calculated_general_score` | Latest eligible overall score |
| `calculated_player_level_id` | Foreign key to PlayerLevel |
| `calculated_from_player_assessment_id` | Source PlayerAssessment row |
| `calculated_at` | Time the projection was calculated |

All fields should be nullable. Add appropriate foreign keys and indexes. Validate that the source PlayerAssessment belongs to the same PlayerProfile.

The calculated fields are server-owned. Strong parameters, mutations and serializers must not permit ordinary clients to set or alter them.

Consider whether a classification configuration version/snapshot is needed for auditability when administrators later change level ranges. At minimum, retain the source score and source assessment. If the application must reproduce the exact historical level assignment after configuration changes, store a classification version or immutable snapshot as part of the projection/history design.

### 6.3 API response

Expose the calculated result through the existing player profile API conventions. An illustrative response shape is:

```json
{
  "calculated_skill_level": {
    "score": 72,
    "code": "AA",
    "name": "Competitive",
    "minimum_score": 65,
    "maximum_score": 79,
    "calculated_at": "2026-11-25T10:00:00Z",
    "source_player_assessment_id": 123,
    "source_assessment_session_id": 45
  }
}
```

This is illustrative only. Adapt names and nesting to the existing serializer/API contract. When no result exists, return a consistent null or explicit unassessed representation rather than fabricating a level.

Preserve the existing `level` API field and its current meaning for backward compatibility.

## 7. Detailed implementation phases

## Phase 0 — Repository audit and technical design

**Goal:** Establish the actual codebase contract before changing code.

### API audit

Inspect:

- `AssessmentDefinition` and its category associations.
- `AssessmentCategory` and category weight validation.
- `AssessmentCategoryScore` and the canonical score calculation.
- `Assessment` and its score semantics.
- `AssessmentSession`, publication timestamp, status transitions, archive/withdraw/retract behavior and immutability.
- `PlayerAssessment`, completion rules, `overall_score`, rank and row status.
- `PlayerProfile`, including the current free-text `level` field.
- Existing level/ranking models, services and consolidation logic.
- Jobs, callbacks, transactions and after-commit patterns.
- Controllers, serializers, routes, policies/authorization and database indexes.
- Existing migrations, seeds, factories and tests.

### Frontend audit

Inspect:

- Player profile pages/components and edit forms.
- Assessment Definition administration screens.
- Assessment Session creation, scoring and publication screens.
- API types/interfaces and request clients.
- Role-based navigation and authorization behavior.
- Existing responsive UI and test patterns.

### Audit deliverable

Produce a report containing:

1. Exact files and classes involved.
2. Existing lifecycle and scoring behavior, backed by code references.
3. Reusable functionality and gaps.
4. Proposed migration/model/service/controller/serializer/job changes.
5. Frontend components and API types to update.
6. Test strategy and deployment risks.

**Exit criteria:** No implementation assumptions remain about publication ordering, score validity, completion or archive semantics. No code changes in this phase.

## Phase 1 — PlayerLevel configuration and dedicated definition

**Goal:** Establish the configurable classification and the dedicated assessment definition.

### Backend tasks

1. Reuse an existing level model if it has the required semantics; otherwise create `PlayerLevel`.
2. Add the seven initial level records and proposed ranges.
3. Add validations/constraints for code uniqueness, score range validity and ordering.
4. Ensure active ranges cover 0–100 without gaps or overlaps.
5. Add a stable system key/purpose to AssessmentDefinition if no equivalent exists.
6. Provision the dedicated definition with key `player_skill_level`.
7. Provision or associate the initial categories and weights, reusing existing category records where possible.
8. Make provisioning idempotent.
9. Apply existing authorization rules to level and definition administration.
10. Respect definition immutability/versioning once sessions reference a definition.

### Frontend tasks

1. Add an administration view for PlayerLevel records if consistent with the existing admin architecture.
2. Allow authorized administrators to edit names, ranges, ordering and active status.
3. Prevent saving invalid or overlapping/gapped ranges.
4. Clearly identify the dedicated Player Skill Assessment definition.
5. Do not expose system keys as ordinary editable display names.

### Tests

- Provisioning creates exactly one dedicated definition.
- Re-running provisioning does not duplicate levels, categories or definitions.
- Codes are unique.
- Boundary values map to the correct levels.
- Invalid ranges and overlaps are rejected.
- All valid scores are covered.
- Existing ordinary definitions remain unaffected.
- Authorization is enforced.

**Exit criteria:** The dedicated definition and configurable classification are available and valid.

## Phase 2 — Persist calculated profile information

**Goal:** Store the calculated result without changing the existing coach-entered field.

### Backend tasks

1. Add the nullable calculated fields or an equivalent projection structure.
2. Add foreign keys and indexes.
3. Add model associations and consistency validations.
4. Ensure the source assessment belongs to the same player profile.
5. Prevent client-side mass assignment of calculated fields.
6. Preserve the existing `PlayerProfile.level` field and API contract.
7. Decide whether a classification version/snapshot is required and document the chosen behavior.

### Tests

- A profile can have no calculated level.
- A profile can store a valid score, level and source assessment.
- A source assessment belonging to another player is rejected.
- Invalid score/level references are rejected.
- API create/update requests cannot forge calculated fields.
- Existing coach-entered `level` remains unchanged.

**Exit criteria:** The database can safely represent the projection and clients cannot write it directly.

## Phase 3 — Recalculation service

**Goal:** Implement a single reliable server-side calculation path.

Suggested service name: `PlayerLevels::RecalculatePlayer`.

### Service responsibilities

1. Accept a PlayerProfile (or stable profile ID).
2. Resolve the currently designated Player Skill Assessment definition/version.
3. Query that player's Assessment Sessions that satisfy the eligibility rules.
4. Select by actual publication timestamp descending and deterministic ID tie-breaker.
5. Find the player's complete PlayerAssessment row.
6. If the newest candidate has no complete row, continue to the next eligible candidate.
7. Read the canonical `overall_score` without recalculating it.
8. Resolve the configured PlayerLevel for that score.
9. Persist score, level, source row and calculation timestamp atomically.
10. Clear the projection if no valid candidate exists.

### Reliability requirements

- Idempotent: running repeatedly with unchanged source data produces the same result.
- Transaction-safe: score, level and source references update together.
- Concurrency-safe: an older job must not overwrite a result based on newer source data. Lock/re-query or use another repository-consistent strategy.
- Efficient: avoid N+1 queries when recalculating every player in a session.
- Observable: log meaningful failures and provide enough context for retry/reconciliation.

### Tests

- Every score boundary (0, 19, 20, 34, 35, 49, 50, 64, 65, 79, 80, 89, 90, 100).
- Latest publication timestamp wins.
- An earlier session date published later wins under publication ordering.
- A newer incomplete row does not replace an earlier valid result.
- Draft sessions are ignored.
- Ordinary assessment definitions are ignored.
- Ineligible sessions are ignored.
- No eligible result clears the projection.
- Repeated calls are idempotent.
- Concurrent/stale execution cannot leave an older projection.

**Exit criteria:** A service can correctly calculate one player's level from existing assessment data.

## Phase 4 — Assessment Session lifecycle integration

**Goal:** Automatically keep calculated levels current as dedicated sessions change lifecycle state.

### Backend tasks

1. Identify the existing successful publication transition and its transaction boundary.
2. After publication commits, identify affected player profiles.
3. Recalculate only players with rows in the qualifying dedicated session, while ensuring fallback behavior remains correct.
4. Use the existing background job conventions if recalculation should be asynchronous.
5. Make jobs retryable and idempotent.
6. Handle any lifecycle transition that makes a previously eligible session ineligible.
7. On withdrawal/retraction or equivalent, recalculate affected players and fall back to their next eligible assessment.
8. Confirm archive behavior and implement according to the actual lifecycle contract.
9. Do not trigger this behavior for ordinary assessment definitions, draft edits or unrelated ranking consolidation workflows.
10. Preserve published session immutability and existing audit behavior.

### Tests

- Publishing a dedicated session updates affected players.
- Publishing an ordinary session does not update calculated levels.
- Draft edits do not update calculated levels.
- Repeated publication/job execution is safe.
- Failed jobs can be retried.
- Making a source session ineligible triggers fallback or clearing.
- Unaffected players are not modified.

**Exit criteria:** Publishing a qualifying assessment updates the calculated levels automatically and lifecycle changes are handled correctly.

## Phase 5 — API and frontend profile display

**Goal:** Make the calculated level available and understandable to users.

### Backend tasks

1. Add calculated skill-level data to the appropriate player profile serializer/API endpoint.
2. Include score, level code/name, range, calculation timestamp and source identifiers/metadata as permitted.
3. Apply existing profile visibility and authorization rules. Do not leak private assessment details through a public profile endpoint.
4. Preserve the existing coach-entered `level` field unchanged.
5. Return a consistent Unassessed/null state.

### Frontend tasks

1. Add a distinct **Calculated Player Skill Level** section to the player profile.
2. Display the level code and description, for example `AA — Competitive`.
3. Display the score out of 100.
4. Optionally display a progress indicator, clearly labelled as the assessment score.
5. Display the date of the source assessment/publication using the appropriate timestamp.
6. Link to the source Assessment Session or PlayerAssessment only if the current routing and permissions support it.
7. Display **Unassessed** when there is no valid source result.
8. Keep the existing coach level/notes in a separate section.
9. Do not display calculated level as the player's tournament division.
10. Respect mobile layouts and existing design conventions.

### Tests

- Serializer returns the calculated result correctly.
- Unassessed profiles return the expected empty state.
- Existing profile consumers remain backward compatible.
- Users cannot view source assessment information they are not authorized to access.
- Frontend renders assessed and unassessed states.
- Coach-entered level and calculated level are visibly separate.

**Exit criteria:** Users can understand the calculated result and its source without confusing it with coach notes or tournament division.

## Phase 6 — Historical backfill and reconciliation

**Goal:** Calculate levels for players with existing qualifying assessments and provide a repair mechanism.

### Backend tasks

1. Add a Rake task or project-standard command, for example:

   ```bash
   bin/rails player_levels:recalculate_all
   ```

2. Support a dry-run mode.
3. Produce a report containing player ID, selected session, publication timestamp, source PlayerAssessment, score and proposed level.
4. Provide a real execution mode that invokes the same calculation service used by normal lifecycle processing.
5. Record/report failures and allow safe retries.
6. Add a reconciliation mode that compares stored projections with current eligible source data.
7. Do not alter historical assessment scores, sessions or `PlayerProfile.level`.
8. Do not infer the dedicated definition by display name; use the stable system key.

### Rollout procedure

1. Run tests and static checks locally/CI.
2. Deploy to staging.
3. Run the dry-run report against staging data.
4. Review unexpected players, missing timestamps, incomplete rows and definition identification.
5. Execute the staging backfill.
6. Verify profile displays and source links.
7. Deploy to production.
8. Run production dry-run and review the report.
9. Execute production backfill in manageable batches if necessary.
10. Monitor errors and run reconciliation after deployment.

### Tests

- Dry-run does not write data.
- Repeated execution is idempotent.
- Failures are reported and can be retried.
- Only dedicated, eligible assessments are considered.
- Existing coach-entered levels and historical assessment records remain unchanged.

**Exit criteria:** Existing profiles are reconciled safely and the operation can be repeated when required.

## 8. Acceptance criteria

The feature is complete when:

1. A dedicated Player Skill Assessment definition is identified by a stable key.
2. Its configured categories and weights total 100%.
3. The existing Assessment Session workflow is reused.
4. The existing `PlayerAssessment.overall_score` is the sole score input.
5. The latest eligible published assessment is selected by actual publication timestamp.
6. Incomplete assessments are never treated as zero.
7. Seven configurable levels (B, BB, BBB, A, AA, AAA, AAAA) are supported.
8. Classification ranges cover 0–100 without gaps or overlaps.
9. Calculated data is separate from `PlayerProfile.level`.
10. No eligible assessment results in Unassessed, not Beginner.
11. Draft and ordinary assessment sessions do not affect calculated levels.
12. An ineligible source causes fallback or clearing.
13. Tournament division remains independent.
14. API visibility and authorization are respected.
15. The frontend displays score, code, description and source information.
16. Historical backfill and reconciliation are idempotent and auditable.
17. Existing assessment, profile and tournament functionality continues to pass regression tests.

## 9. AI implementation prompts

Use these prompts sequentially. Run the repository audit first and require the coding agent to report its findings before implementation. Each later prompt should be adapted to the exact files and conventions found in the audit.

### Prompt 1 — Repository audit (no code changes)

```text
Audit the BeachVolleyballHub API and frontend repositories for the
implementation of a calculated Player Skill Level feature.

Inspect the existing AssessmentDefinition, AssessmentCategory,
AssessmentCategoryScore, Assessment, AssessmentSession,
PlayerAssessment, scoring services, PlayerProfile, publication lifecycle,
authorization, API serializers/controllers, frontend profile components,
assessment screens and tests.

The feature must use a dedicated Player Skill Assessment definition
and the latest eligible published Assessment Session.

Do not change any code yet.

Identify exact files, existing behavior, reusable services, missing
functionality, risks and a recommended implementation sequence.

Verify the real publication timestamp and session lifecycle. Do not
assume session_date or created_at is the publication order. Confirm how
incomplete rows, archived sessions, withdrawn/retracted sessions and
published-session immutability currently work.

Return an audit report with file paths, relevant classes/methods,
existing API contracts, migration recommendations and a test plan.
```

### Prompt 2 — Configurable levels and dedicated definition

```text
Implement the configurable PlayerLevel classification and the dedicated
Player Skill Assessment definition in BeachVolleyballHub, following the
repository audit and existing project conventions.

Initial classification:
B: 0-19 — Beginner
BB: 20-34 — Developing
BBB: 35-49 — Intermediate
A: 50-64 — Advanced
AA: 65-79 — Competitive
AAA: 80-89 — High Performance
AAAA: 90-100 — Elite

These are configurable starting ranges, not official tournament
division equivalences. Keep calculated skill level independent from
tournament registration division.

Use database-backed configurable level records, not hardcoded range
logic. Validate unique codes, valid inclusive ranges, ordering and
complete non-overlapping coverage of scores 0-100.

Create or reuse a stable system key for the dedicated assessment
definition: player_skill_level. Do not identify it by display name.
Provision it idempotently, reusing existing categories where appropriate.
Initial weights:
Serving 15%; Passing 20%; Setting 15%; Attacking 20%;
Defense and Blocking 20%; Tactical Understanding 10%.

Respect existing definition immutability/versioning. Apply existing
admin authorization. Add migrations, provisioning/seeds, UI if required
by the existing admin architecture, and comprehensive tests.

Before finishing, summarize files changed, migrations, behavior and tests.
```

### Prompt 3 — Separate calculated profile storage

```text
Implement storage for the calculated Player Skill Level, following the
approved repository audit and existing Rails conventions.

Keep PlayerProfile.level unchanged. It is the existing coach-entered
free-text level/notes field and must never be overwritten by this feature.

Store the calculated score, configured PlayerLevel reference, source
PlayerAssessment reference and calculation timestamp. Reuse an existing
equivalent projection structure if one exists; otherwise add nullable
fields to PlayerProfile or an appropriate dedicated projection model.

Add foreign keys, indexes, associations and consistency validations.
Ensure the source PlayerAssessment belongs to the same PlayerProfile.
Calculated fields must be server-owned and rejected/ignored in ordinary
client create/update parameters.

Consider and document how classification-range changes affect historical
level reproducibility. Add tests for null state, valid persistence,
invalid source ownership, invalid references and protection against
client writes. Run relevant regression tests.
```

### Prompt 4 — Calculation service

```text
Implement PlayerLevels::RecalculatePlayer using the actual models and
lifecycle behavior discovered in the repository audit.

The service must:
1. Resolve the currently designated Player Skill Assessment definition
   using its stable system key/purpose.
2. Find the player's eligible published sessions for that definition.
3. Order by the real publication timestamp descending, with a stable
   deterministic tie-breaker.
4. Exclude sessions that are ineligible under the real lifecycle rules.
5. Find the player's complete PlayerAssessment row. If a newer session
   has no complete valid row, continue to the next eligible result.
6. Read the existing PlayerAssessment.overall_score. Do not recalculate
   category weights or create a second scoring engine.
7. Map the score to the configured PlayerLevel.
8. Persist score, level, source assessment and calculated_at atomically.
9. Clear the projection if no eligible complete result exists.

Make the service idempotent, transaction-safe and safe against stale or
concurrent jobs overwriting a newer result. Follow project conventions
for query objects/services and logging.

Add tests for every classification boundary, latest publication order,
older session_date published later, incomplete rows, draft sessions,
ordinary definitions, ineligible sessions, no result, idempotency and
concurrency/stale execution.

Do not change unrelated ranking consolidation behavior.
```

### Prompt 5 — Assessment Session lifecycle integration

```text
Integrate PlayerLevels::RecalculatePlayer with the existing
AssessmentSession lifecycle.

After a qualifying Player Skill Assessment session is successfully
published and the transaction commits, recalculate the affected players.
Use the existing job/callback/after-commit patterns. If asynchronous,
make the job retryable and idempotent.

Do not recalculate for ordinary assessment definitions, draft edits or
unrelated session changes.

Handle any transition that makes a previously eligible session
ineligible, including the actual withdrawal/retraction behavior present
in this application. Recalculate affected players so they fall back to
the next latest eligible complete result or become Unassessed.

Confirm archive semantics from the code and implement accordingly; do
not assume archived sessions are eligible or ineligible.
Preserve published-session immutability and audit behavior.

Add tests for publication, affected-player selection, ordinary-session
exclusion, retry, repeated execution, fallback and clearing.
Run the relevant API regression suite.
```

### Prompt 6 — API and frontend integration

```text
Expose calculated Player Skill Level through the existing player
profile API and frontend.

API:
- Include score, level code/name, configured range, calculated_at and
  source assessment/session identifiers or permitted metadata.
- Return a consistent Unassessed/null state when no eligible result exists.
- Preserve the existing PlayerProfile.level field and its semantics.
- Apply existing profile visibility and authorization rules. Do not leak
  assessment details to users who cannot access the source assessment.
- Follow the current serializer and API response conventions.

Frontend:
- Add a distinct Calculated Player Skill Level section to the player
  profile.
- Display code and description (for example, AA — Competitive), score
  out of 100, assessment date and source information where permitted.
- Show Unassessed when there is no valid result.
- Keep coach-entered level/notes in a separate section.
- Do not present this value as the tournament registration division.
- Follow existing responsive design, component and API type conventions.

Add backend serializer/authorization tests and frontend tests for
assessed, unassessed, permissions and separation from coach notes.
Run frontend build/type checks and relevant test suites.
```

### Prompt 7 — Historical backfill and reconciliation

```text
Implement a safe, idempotent historical backfill and reconciliation
process for calculated Player Skill Levels.

Use the same PlayerLevels::RecalculatePlayer service as normal runtime
updates. Identify the dedicated definition by stable system key, not
its display name.

Provide a command such as:
  bin/rails player_levels:recalculate_all

Support a dry-run mode that makes no writes and reports each player's
selected source session, publication timestamp, PlayerAssessment,
score and proposed level. Provide an execution mode, batching if needed,
and clear reporting of failures with safe retry behavior.

Add reconciliation capability to detect stale/missing projections.
Never modify historical assessment scores, published session content
or PlayerProfile.level. Do not invent publication timestamps for legacy
sessions where the actual publication time cannot be established.

Add tests proving dry-run has no side effects, execution is idempotent,
failures are visible/retryable and unrelated assessments are excluded.
Document staging and production rollout, verification and rollback.
```

### Prompt 8 — Final review and release readiness

```text
Perform a final end-to-end review of the Player Skill Level feature
across the BeachVolleyballHub API and frontend repositories.

Verify all acceptance criteria in the implementation specification:
- dedicated stable-key Player Skill Assessment definition;
- category weights total 100%;
- existing overall_score is the only score input;
- latest eligible published session selected by actual publication time;
- incomplete rows never become zero;
- configurable B/BB/BBB/A/AA/AAA/AAAA ranges cover 0-100;
- calculated fields remain separate from PlayerProfile.level;
- no result displays as Unassessed;
- lifecycle fallback/clearing works;
- tournament divisions remain independent;
- authorization and assessment visibility are respected;
- backfill and reconciliation are safe and idempotent.

Run relevant API and frontend tests, linting, type checks and production
builds. Inspect migrations and query performance. Identify any missing
tests, security issues, N+1 queries, race conditions or deployment risks.

Do not claim completion for checks that were not actually run. Return a
release checklist, changed-file summary, test results and any remaining
limitations.
```

## 10. Suggested delivery sequence

| Order | Phase | Main deliverable |
|---:|---|---|
| 1 | Phase 0 | Repository audit and verified technical design |
| 2 | Phase 1 | Configurable levels and dedicated assessment definition |
| 3 | Phase 2 | Separate calculated profile storage |
| 4 | Phase 3 | Recalculation service |
| 5 | Phase 4 | Publication/lifecycle integration |
| 6 | Phase 5 | API and frontend profile display |
| 7 | Phase 6 | Historical backfill and reconciliation |
| 8 | Final review | Regression, security and release readiness |

Recommended approach: complete and review each phase before asking the AI coding agent to proceed to the next. Commit or checkpoint working code between phases so regressions can be isolated and reverted.

## 11. Open point before implementation

The level labels are established as the proposed classification vocabulary, but the numeric thresholds and descriptions above remain proposed starting values. Confirm those ranges before treating them as final production policy. They should remain configurable regardless.
