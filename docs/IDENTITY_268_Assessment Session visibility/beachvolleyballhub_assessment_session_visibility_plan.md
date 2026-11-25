# BeachVolleyballHub -- AssessmentSession Visibility

## Detailed Implementation Plan and AI Coding Prompts

**Status:** Approved implementation plan\
**Date:** 24 November 2026\
**Backend:** Ruby on Rails API\
**Frontend:** React + TypeScript + Vite\
**Database:** PostgreSQL\
**Repositories:** - Frontend:
https://github.com/romalopes/beachvolleyballhub_frontend - API:
https://github.com/romalopes/beachvolleyballhub_api

------------------------------------------------------------------------

# 0. Implementation progress

**Tracker:** [`phases/README.md`](./phases/README.md) — one document per phase under `phases/`.

| Phase | Title | Status | Doc |
|-------|-------|--------|-----|
| 0 | Repository & working-tree verification | Done (24 Nov 2026) | phases/phase-00-repository-verification.md |
| 1 | Codebase inspection & architecture report | Done (24 Nov 2026) | phases/phase-01-architecture-report.md |
| 2 | Authorization & data contract | Draft — awaiting owner approval | phases/phase-02-authorization-and-data-contract.md |
| 3 | Database migration & model | Done (24 Nov 2026) | phases/phase-03-database-migration-and-model.md |
| 4 | Centralized authorization policy | Done (24 Nov 2026) | phases/phase-04-centralized-authorization-policy.md |
| 5 | API retrieval, visibility updates & sharing links | Done (24 Nov 2026) | phases/phase-05-api-retrieval-visibility-updates-sharing.md |
| 6 | Protect nested resources & media | Done (24 Nov 2026) | phases/phase-06-protect-nested-resources-media.md |
| 7 | Frontend visibility settings & indicators | Done (24 Nov 2026) | phases/phase-07-frontend-visibility-settings-indicators.md |
| 8 | Unlisted sharing experience | Done (24 Nov 2026) | phases/phase-08-unlisted-sharing-experience.md |
| 9 | Routing, login continuation & listing behavior | Done (24 Nov 2026) | phases/phase-09-routing-login-continuation-listing.md |
| 10 | Audit logging | Done (24 Nov 2026) | phases/phase-10-audit-logging.md |
| 11 | Security review & integration testing | Done (24 Nov 2026) | phases/phase-11-security-review-integration.md |

Key adaptations recorded in Phase 1 (details in the phase docs): D1 visibility as a string column per repo convention; D2 digest-only share tokens; D3 AssessmentSession has no organisation association (Q1 open); D4 draft/withdrawn lifecycle interaction.

**Gate:** per section 7 exit criteria, implementation (Phase 3+) starts only after the owner approves the Phase 2 contract.

## 1. Purpose

Implement visibility controls for `AssessmentSession` so coaches can
decide who can view an assessment while keeping viewing permissions
separate from editing and management permissions.

The feature has four visibility levels:

  -----------------------------------------------------------------------
  Value                   Authentication          Who can view
  ----------------------- ----------------------- -----------------------
  `public`                Required                Any registered
                                                  BeachVolleyballHub user

  `unlisted`              Not required            Anyone possessing the
                                                  active sharing link

  `internal`              Required                Organization members,
                                                  explicitly assigned
                                                  coaches, and involved
                                                  players

  `private`               Required                Authorized coaches and
                                                  BeachVolleyballHub
                                                  administrators
  -----------------------------------------------------------------------

**Default:** `internal`.

### Confirmed product decisions

1.  New assessment sessions default to `internal`.
2.  Internal access includes both:
    -   Authorized members of the organization associated with the
        assessment.
    -   Explicitly assigned coaches and players involved in that
        assessment.
3.  Public access requires a registered, authenticated BVBH account.
4.  Unlisted access does not require registration or login.
5.  Visibility controls viewing only. It does not grant editing,
    deleting, commenting, or administrative permissions.

## 2. Important architecture decisions

### 2.1 Separate resource identity from sharing authorization

Use two separate values:

-   `public_slug`: stable, human-readable identifier for the
    assessment's normal application URL. It is not a secret and does not
    grant access.
-   `share_token_digest`: digest of a high-entropy unlisted sharing
    token. Possession of the corresponding raw token grants read-only
    access while the assessment is unlisted.

Suggested frontend routes:

``` text
/assessments/:public_slug
/assessments/share/:share_token
```

Do not expose sequential database IDs in externally shared URLs.
Existing internal API IDs may need to remain temporarily for backward
compatibility; inspect actual usage before changing them.

### 2.2 Avoid storing raw sharing tokens

Generate a token using a cryptographically secure random generator, for
example:

``` ruby
SecureRandom.urlsafe_base64(24)
```

Store only a SHA-256 digest:

``` ruby
Digest::SHA256.hexdigest(token)
```

Return the raw token only in the response that creates or regenerates
the link. Never log it, persist it in plaintext, include it in
analytics, or expose it in error messages.

The initial release supports one active unlisted token per assessment.
Regenerating it replaces the digest and immediately invalidates the
previous token.

### 2.3 Centralize authorization

Use the authorization framework already present in the repository. If
there is no established policy framework, introduce a focused
`AssessmentSessionPolicy` (or the project's equivalent).

Do not duplicate visibility checks across controllers, serializers,
React components, or nested-resource controllers.

### 2.4 Inspect before changing

The AI coding tool must inspect both repositories and the existing
domain model before implementation. It must not assume model names,
association names, role names, route conventions, serializer libraries,
or authorization gems based only on this plan.

The implementation must reuse existing BeachVolleyballHub conventions
wherever possible.

------------------------------------------------------------------------

# 3. Business rules

## 3.1 Public

-   Authentication is mandatory.
-   Any registered BVBH user can view the assessment, regardless of
    organization membership.
-   Public does not mean anonymous or search-engine accessible.
-   Public assessments may appear in authenticated platform
    discovery/listing features if such features exist and product
    requirements support them.
-   Public visibility must not expose restricted personal information,
    private coaching notes, or unrelated player data.
-   Viewing does not grant editing rights.

## 3.2 Unlisted

-   No login or registration is required.
-   A valid sharing token is required.
-   The token grants read-only access to the permitted assessment
    representation.
-   Unlisted assessments do not appear in ordinary listings, searches,
    feeds, or discovery.
-   The page/API response should discourage indexing
    (`noindex, nofollow` where applicable).
-   Regenerating the link invalidates the previous token immediately.
-   Changing visibility away from `unlisted` invalidates or disables the
    active share token.
-   Do not allow an unlisted token to act as a user identity or bypass
    unrelated application security controls.

## 3.3 Internal

Access is granted to any of the following, provided the relationship is
active and valid:

1.  An authorized member of the organization associated with the
    assessment.
2.  A coach explicitly assigned to the assessment.
3.  A player involved in the assessment.

Additional rules:

-   A player does not gain access merely by belonging to the
    organization; they must be involved in the assessment.
-   An assigned coach may qualify even if not an ordinary organization
    member.
-   Membership, player involvement, and coach assignment must be checked
    using the actual existing relationships.
-   Access is revoked when the qualifying membership or assignment is
    removed.
-   Other organizations do not gain access.

## 3.4 Private

-   Only coaches authorized to view/manage that assessment and BVBH
    administrators can view it.
-   Ordinary organization membership alone does not grant access.
-   Involved players cannot view it.
-   A coach's access does not automatically grant edit or delete rights.
-   Apply the platform's existing administrator role/permission
    semantics; do not assume every user with a loosely named role is a
    platform administrator.

## 3.5 Administrator override

BVBH administrators may retain platform-level access for support and
moderation, according to existing role/permission rules. Administrative
access should be auditable. Do not grant administrator permissions based
on frontend role labels.

## 3.6 Read versus manage

Define separate policy capabilities, at minimum:

-   View assessment.
-   Update assessment.
-   Delete assessment.
-   Manage visibility.
-   Generate/regenerate sharing link.
-   Manage assessment participants/assignments.
-   Create or edit comments/feedback, if those features exist.

A user who can view must not automatically be able to modify anything.

------------------------------------------------------------------------

# 4. Data model proposal

The proposed database fields are:

  -----------------------------------------------------------------------
  Field                   Type                    Purpose
  ----------------------- ----------------------- -----------------------
  `visibility`            integer                 Visibility enum

  `public_slug`           string                  Stable URL identifier

  `share_token_digest`    string, nullable        Digest of current
                                                  unlisted token
  -----------------------------------------------------------------------

Potential enum:

``` ruby
enum :visibility, {
  public: 0,
  unlisted: 1,
  internal: 2,
  private: 3
}, default: :internal
```

Confirm Rails version and the repository's enum style before
implementing. Use the project's conventions.

### Indexes and constraints

-   Unique index on `public_slug`.
-   Unique index on `share_token_digest` (nullable values are allowed by
    PostgreSQL unique indexes).
-   Index on `visibility` only if query patterns justify it; avoid
    adding low-value indexes automatically.
-   Review existing foreign-key and join-table indexes for organization
    membership, assigned coaches, and involved players.
-   Add database constraints where appropriate, not just model
    validations.

### Slug behavior

-   Generate a unique, human-readable slug with a random suffix.
-   Keep it stable when the assessment title changes.
-   Do not derive authorization from the slug.
-   Handle collisions safely.
-   Do not assume a slug change is needed when visibility changes.

### Token lifecycle

-   Generate only when an assessment is made unlisted and a link is
    requested, or according to the agreed UX.
-   Return the raw token once.
-   Store only its digest.
-   Regenerate by replacing the digest atomically.
-   Clear the digest when leaving unlisted visibility, unless product
    review establishes a different explicit lifecycle.
-   Never put raw tokens in Rails logs, exception trackers, audit
    records, or analytics.

------------------------------------------------------------------------

# 5. Resource and privacy boundaries

The parent `AssessmentSession` access decision must protect all nested
resources that belong to it.

Inspect and cover, where present:

-   Assessment session details.
-   Session participants.
-   Player associations.
-   Assessment records and skill assessments.
-   Scores and results.
-   Comments and feedback.
-   Coach-only notes.
-   Analysis videos and video metadata.
-   ActiveStorage attachments.
-   Cloudflare R2 objects or other media storage.
-   Reports, exports, and download endpoints.
-   Any related notification or preview endpoint that reveals assessment
    data.

### 5.1 Public/unlisted response shaping

Do not return every field simply because a viewer can access the
session.

Review serializers and define a safe external/read-only representation.
At minimum, do not expose:

-   Email addresses.
-   Phone numbers.
-   Private profile attributes.
-   Internal coach notes.
-   Administrative comments.
-   Unrelated personal information.
-   Private identifiers that are not needed by the viewer.

Determine whether player names, profile photos, age/date-of-birth,
results, and video content may be shown. Do not invent consent rules;
identify existing privacy settings and product requirements. Flag
unresolved consent decisions for the project owner.

### 5.2 Comments and feedback

Inspect current comment/feedback semantics. Separate shareable feedback
from coach-only/internal notes if the current model supports or needs
this distinction. Do not make all comments visible to unlisted viewers
by default.

### 5.3 Media security

-   Authorize the parent assessment before issuing a media URL.
-   Use short-lived signed URLs for protected media where supported.
-   Do not return permanent public storage URLs for private/internal
    media.
-   Check whether the current ActiveStorage/R2 configuration bypasses
    Rails authorization.
-   Explain the limits of revocation: already-issued signed URLs may
    remain usable until expiry. Choose a short, documented expiry
    appropriate to the media delivery architecture.
-   Avoid caching token-protected responses in shared/public caches.

------------------------------------------------------------------------

# 6. API and frontend behavior

The exact routes must follow the existing API conventions. The following
are target behaviors, not instructions to create duplicate endpoints if
equivalent routes already exist.

## 6.1 Standard assessment retrieval

Target:

``` http
GET /api/v1/assessment_sessions/:public_slug
```

Requires authentication. The policy decides whether the current user can
view the assessment.

## 6.2 Unlisted retrieval

Target:

``` http
GET /api/v1/assessment_sessions/share/:share_token
```

No authentication required. Resolve using a digest comparison/query and
return a restricted read-only representation only if:

-   A matching digest exists.
-   The assessment is still `unlisted`.
-   The token has not been revoked.

Use a not-found response for invalid/revoked tokens to avoid disclosing
resource existence.

## 6.3 Visibility update

Use the existing update endpoint and strong-parameter conventions. Only
an authorized coach/manager may change visibility.

Example payload:

``` json
{
  "assessment_session": {
    "visibility": "internal"
  }
}
```

Reject unknown values with the application's standard validation
response.

## 6.4 Generate/regenerate link

Target:

``` http
POST /api/v1/assessment_sessions/:public_slug/regenerate_share_link
```

-   Requires authenticated management permission.
-   Assessment must be `unlisted`.
-   Generate a new token and replace the digest atomically.
-   Return the share URL once.
-   Do not include the token in subsequent normal assessment responses.

If the project prefers token creation as part of changing visibility to
unlisted, document and implement one consistent flow.

## 6.5 Status codes

Follow existing API conventions. Expected behavior:

  -----------------------------------------------------------------------
  Situation                           Expected result
  ----------------------------------- -----------------------------------
  Invalid slug                        404

  Invalid/revoked token               404

  Unauthorized access                 403 or 404 according to existing
                                      disclosure policy

  Invalid visibility                  422

  Unauthorized visibility update      403

  Successful read                     200

  Successful token generation         200 or 201, consistent with API
                                      conventions
  -----------------------------------------------------------------------

## 6.6 Frontend

Add a visibility selector to assessment creation/editing:

-   Public -- all registered BVBH users.
-   Unlisted -- anyone with the link.
-   Internal -- organization members, assigned coaches and involved
    players.
-   Private -- authorized coaches and BVBH administrators.

Default selection: Internal.

Show clear descriptions and a visibility indicator on relevant
assessment cards, details, and management lists.

For Unlisted sessions provide:

-   Copy link.
-   WhatsApp sharing.
-   Native device sharing when supported.
-   Regenerate link with a confirmation dialog.
-   Display the newly generated link only when returned by the
    generation request.

For Public sessions, anonymous visitors should be directed to login and
returned to the original assessment after successful authentication.

Private assessments must not appear in player-facing lists.

------------------------------------------------------------------------

# 7. Implementation phases and AI prompts

Run the prompts in order. Each prompt is intended for Codex or another
coding agent with access to the local frontend and API repositories.

**Important working rule:** Ask the coding agent to inspect first,
report its findings, and make only the changes requested in that phase.
Do not ask it to implement all phases in one run.

## Phase 0 -- Repository and working-tree verification

### Goal

Confirm the correct repositories, branches, working trees, and project
instructions before touching code.

### AI prompt

``` text
We are going to implement the BeachVolleyballHub AssessmentSession visibility feature.

Repositories:
- API: https://github.com/romalopes/beachvolleyballhub_api
- Frontend: https://github.com/romalopes/beachvolleyballhub_frontend

First, inspect the local workspace. Do not modify any files yet.

1. Confirm which directory is the Rails API and which is the React/Vite frontend.
2. Check the current branch and git working-tree status in both repositories.
3. Read the repository instructions and relevant README/development documentation.
4. Identify the Rails, Ruby, Node and package-manager versions from the project files.
5. Identify existing test commands for backend and frontend.
6. Check whether either repository contains uncommitted user work.

Do not reset, stash, overwrite, or discard any changes.
Do not switch branches.
Do not implement anything.

Return:
- Repository paths and branch names.
- Working-tree status.
- Relevant project conventions.
- Test commands.
- Any blockers or discrepancies.
Wait for approval before proceeding.
```

### Deliverable

A verified workspace report. Resolve any wrong repository, branch, or
uncommitted-work issue before continuing.

------------------------------------------------------------------------

## Phase 1 -- Codebase inspection and architecture report

### Goal

Discover the real domain model and authorization structure. No
implementation yet.

### AI prompt

``` text
Inspect the BeachVolleyballHub API and frontend to prepare the implementation of AssessmentSession visibility.

Do not modify files or run database migrations.

Backend inspection:
1. Find the AssessmentSession model, migration history, controllers, routes, serializers and services.
2. Identify all AssessmentSession associations and dependent resources.
3. Find how organizations and organization memberships are represented.
4. Find how coaches are associated with organizations and assessment sessions.
5. Find how players are represented and how a player is associated with an assessment session.
6. Inspect the existing account/person/player/coach identity model. Do not assume a user is the same record as a player or person.
7. Identify roles, permissions and the BVBH administrator definition.
8. Identify the authorization framework or existing policy/service patterns.
9. Find all endpoints that can expose or modify assessment data, including nested resources, videos, attachments, comments and exports.
10. Inspect ActiveStorage, Cloudflare R2 or other media delivery and determine whether URLs bypass Rails authorization.
11. Identify current API route identifiers and frontend route usage.
12. Find existing audit/history logging patterns.
13. Identify relevant model, request, policy and integration tests.

Frontend inspection:
1. Find assessment session creation, editing, detail and listing components.
2. Find API client/service/types for assessment sessions.
3. Find authentication and route-guard patterns.
4. Find player and coach dashboard/listing behavior.
5. Find existing visibility, sharing, copy-link, WhatsApp and native-share UI patterns, if any.
6. Identify component and test conventions.

Return an architecture report with:
- Exact file paths and relevant classes/components.
- Actual association names and authorization rules.
- Current endpoint inventory.
- Current media access behavior.
- Recommended implementation points.
- Migration risks and backward-compatibility concerns.
- Any unresolved product decisions.

Do not invent missing relationships. Explicitly flag anything that cannot be established from the code.
Do not implement the feature yet.
```

### Deliverable

An architecture report with exact file paths, associations, current
permission behavior, API inventory, and migration risks.

### Exit criteria

Do not continue until the owner has reviewed the report and resolved any
important ambiguity, especially:

-   What qualifies as an authorized coach for a private assessment?
-   Which organization membership statuses are active?
-   How are involved players linked?
-   Which child resources contain coach-only or personal information?
-   Which media endpoints can bypass normal authorization?

------------------------------------------------------------------------

## Phase 2 -- Finalize authorization and data contract

### Goal

Translate the inspection findings into precise, testable rules before
migrations.

### AI prompt

``` text
Using the approved AssessmentSession visibility specification and your Phase 1 architecture report, prepare the detailed authorization and API data contract.

Do not modify application code or run migrations.

Define:
1. The exact meaning of organization member using the real membership model and statuses.
2. The exact relationship that makes a coach assigned/authorized for an assessment.
3. The exact relationship that makes a player involved in an assessment.
4. The exact BVBH administrator permission using existing roles/permissions.
5. View, update, delete, manage-visibility and regenerate-link permissions separately.
6. The policy decision for every combination of visibility and user type.
7. Which fields and nested resources are safe for unlisted access.
8. Which data is visible to authenticated public users.
9. Which resources require additional coach-only or player-specific authorization.
10. The intended API request/response shapes and route conventions.
11. How existing routes and clients remain compatible during rollout.
12. The behavior when an assessment changes from unlisted to another visibility.

Pay special attention to:
- Public requires authentication but not organization membership.
- Unlisted requires the valid link and grants read-only access.
- Internal grants access to qualifying organization members, assigned coaches and involved players.
- Private grants access only to authorized coaches and BVBH administrators.
- Visibility never grants editing rights.

Produce:
- A permission matrix.
- A resource/field exposure matrix.
- A proposed policy interface.
- An API contract.
- A list of unresolved questions.

Do not implement until the owner approves the contract.
```

### Deliverable

Approved authorization matrix and API contract.

------------------------------------------------------------------------

## Phase 3 -- Database migration and model

### Goal

Introduce the visibility, stable slug, and sharing-token digest safely.

### AI prompt

``` text
Implement the AssessmentSession database and model changes approved in Phases 1 and 2.

Before editing, re-check the working tree and preserve all existing user changes.

Requirements:
1. Add visibility with values public, unlisted, internal and private.
2. Default new records to internal at both model and database level where appropriate.
3. Add a unique public_slug.
4. Add a nullable unique share_token_digest.
5. Generate a stable, human-readable slug with a cryptographically secure random suffix.
6. Keep the slug stable when the assessment title changes.
7. Generate unlisted tokens using a cryptographically secure random generator.
8. Store only a SHA-256 digest of the raw token.
9. Return the raw token only through an explicit generation operation; never persist or log it.
10. Implement atomic token replacement/regeneration.
11. Clear or invalidate the token when visibility changes away from unlisted.
12. Handle slug/token collisions safely.
13. Follow the Rails and database conventions discovered in Phase 1.

Migration requirements:
- Inspect existing records and choose a conservative backfill.
- Preserve existing effective access; do not unintentionally broaden access.
- Generate slugs for existing assessment sessions.
- Ensure migration is safe for production data and does not rely on loading all records into memory.
- Consider batching for large tables.
- Do not make assumptions about existing data volume; report the migration strategy.

Tests:
- Default visibility.
- Valid enum values.
- Slug generation and uniqueness.
- Slug stability.
- Token generation and digest storage.
- Raw token not persisted.
- Token replacement invalidates the previous token.
- Token clearing when leaving unlisted.
- Collision handling.

Do not modify authorization controllers or frontend components in this phase.
Run focused tests and report changed files, migration name, commands and results.
Do not run the production migration.
```

### Deliverable

Model, migration, indexes/constraints, and focused model tests.

### Exit criteria

Review the migration and test results before proceeding. Confirm the
backfill does not broaden existing access.

------------------------------------------------------------------------

## Phase 4 -- Centralized authorization policy

### Goal

Implement the visibility rules using the actual domain relationships.

### AI prompt

``` text
Implement centralized AssessmentSession authorization using the approved Phase 2 permission matrix and actual relationships discovered in Phase 1.

First inspect the current working tree. Preserve unrelated changes.

Requirements:
1. Reuse the existing authorization framework if present.
2. Otherwise introduce a focused AssessmentSessionPolicy following project conventions.
3. Implement separate decisions for:
   - show/view
   - update
   - destroy
   - manage visibility
   - regenerate share link
   - any existing participant/assessment management actions that need separate checks
4. Public: any authenticated registered user can view.
5. Unlisted: standard authenticated access must not bypass the token requirement unless an explicitly approved administrator override applies. Token access will be handled by the dedicated public-share flow.
6. Internal: qualifying organization members, explicitly assigned coaches and involved players can view.
7. Private: only authorized coaches and BVBH administrators can view.
8. A player's organization membership alone must not grant access to an internal assessment unless the approved policy explicitly says otherwise.
9. Viewing must not grant editing.
10. Membership/assignment removal must revoke access on the next authorization check.
11. Use actual account/person/player relationships and active membership statuses.
12. Avoid N+1 queries where practical, without weakening correctness.

Add policy tests for:
- Anonymous user.
- Registered user outside the organization.
- Organization member.
- Assigned coach.
- Unassigned coach.
- Involved player.
- Uninvolved player.
- BVBH administrator.
- Removed organization member.
- Removed coach assignment.
- Each visibility level.
- View versus update/delete/manage permissions.

Do not duplicate policy logic in controllers or React.
Do not yet refactor every nested endpoint; report the full list of endpoints requiring policy enforcement.
Run focused tests and report results.
```

### Deliverable

Centralized policy and comprehensive policy tests.

------------------------------------------------------------------------

## Phase 5 -- API retrieval, visibility updates and sharing links

### Goal

Expose the new behavior through the Rails API.

### AI prompt

``` text
Implement the AssessmentSession visibility API using the approved API contract and centralized policy.

Preserve existing API conventions and backward compatibility where practical.

Implement/adapt:

1. Standard assessment retrieval by public_slug.
   - Requires authentication.
   - Authorizes through AssessmentSession policy.
   - Does not use slug secrecy as authorization.

2. Unlisted retrieval by share token.
   - No authentication required.
   - Hash the supplied token and find the matching digest.
   - Confirm the assessment is still unlisted.
   - Return only the approved read-only representation.
   - Invalid/revoked tokens should return the agreed not-found response.
   - Never return the stored digest.

3. Visibility update.
   - Only authorized coaches/managers can change visibility.
   - Validate the enum.
   - Apply token invalidation rules when leaving unlisted.
   - Record an audit event if the audit mechanism is ready.

4. Generate/regenerate sharing link.
   - Requires authenticated management permission.
   - Requires the assessment to be unlisted, unless the approved contract specifies a single atomic transition-and-generate operation.
   - Generate a new token and replace the digest atomically.
   - Return the full share URL once.
   - Never log the token or include it in normal show/index responses.

5. Assessment lookup:
   - Use public_slug for the new external/frontend route.
   - Keep existing ID-based API routes temporarily if other clients depend on them.
   - Do not break existing integrations without an explicit migration plan.

6. Error handling:
   - Follow existing response format and status conventions.
   - Do not disclose existence of private assessments to unauthorized users.

Add request tests for:
- Public access requires login.
- Unlisted valid token works without login.
- Invalid and revoked token fail.
- Token fails after visibility changes away from unlisted.
- Internal and private access.
- Visibility update authorization.
- Token generation authorization.
- Token is not returned by normal retrieval.
- Raw token is not logged.
- Slug route and any compatibility route behave correctly.

Run relevant tests. Report all routes, response shapes and changed files.
```

### Deliverable

Working API endpoints, request tests, and updated API documentation.

------------------------------------------------------------------------

## Phase 6 -- Protect nested resources and media

### Goal

Ensure visibility cannot be bypassed through child endpoints, downloads,
or media URLs.

### AI prompt

``` text
Perform a complete authorization pass over every resource associated with AssessmentSession.

Use the Phase 1 endpoint inventory and the approved resource/field exposure matrix.

Inspect and protect, where present:
- Participants and player associations.
- Assessment records and skills.
- Scores/results.
- Comments and feedback.
- Coach-only notes.
- Videos and video metadata.
- ActiveStorage attachments.
- Cloudflare R2 or other object-storage URLs.
- Reports and exports.
- Any related endpoints that expose assessment information.

Requirements:
1. Every nested endpoint must authorize access through its parent AssessmentSession.
2. Do not rely on frontend hiding.
3. Apply the correct read/edit permissions independently.
4. Public and Unlisted responses must use the approved restricted serializer/representation.
5. Do not expose email, phone, private profile attributes, internal notes or unrelated personal data.
6. Do not expose permanent public storage URLs for protected resources.
7. Authorize before issuing signed media URLs.
8. Use short-lived signed URLs where supported.
9. Document the residual exposure window for already-issued signed URLs.
10. Prevent shared/public caching of token-protected responses.
11. Ensure an unlisted token cannot be used to modify comments, scores, assessments or participants.
12. Avoid changing unrelated media behavior.

Add request/service tests for direct access to every protected child resource, including unauthorized and revoked access.

Produce an endpoint coverage checklist showing each resource, its parent authorization check, and test coverage.
Run focused and relevant regression tests.
```

### Deliverable

Protected nested endpoints and media, plus an endpoint coverage
checklist.

------------------------------------------------------------------------

## Phase 7 -- Frontend visibility settings and indicators

### Goal

Allow coaches to configure and understand assessment visibility.

### AI prompt

``` text
Implement the AssessmentSession visibility user interface in the BeachVolleyballHub React/TypeScript frontend.

First inspect current frontend patterns and preserve existing working-tree changes.

Requirements:

1. Update AssessmentSession TypeScript types/API client to support:
   - public
   - unlisted
   - internal
   - private
   - public_slug
   Do not expose share_token_digest to the frontend.

2. Add a visibility selector to assessment creation and editing.
   - Default new sessions to internal.
   - Explain each option clearly.
   - Public: any registered BVBH user can view.
   - Unlisted: anyone with the link can view without login.
   - Internal: organization members, assigned coaches and involved players.
   - Private: authorized coaches and BVBH administrators.

3. Add visibility indicators to relevant:
   - Assessment cards.
   - Assessment detail page.
   - Coach management/list pages.
   - Other existing assessment lists where appropriate.

4. Use consistent icons:
   - Public: globe
   - Unlisted: link
   - Internal: users
   - Private: lock

5. Do not duplicate backend authorization logic in the frontend. The frontend may hide unavailable actions for usability, but the API remains authoritative.

6. Ensure unauthorized users receive a clear, consistent access-denied or not-found experience.

7. Preserve existing responsive/mobile design and accessibility conventions.

8. Do not add a new UI library unless the repository already uses it or there is an approved reason.

Add/update component and API-client tests. Run lint, type checking, and relevant tests. Report changed files and screenshots or a concise description of the resulting screens.
```

### Deliverable

Visibility selector, descriptions, indicators, updated types and
frontend tests.

------------------------------------------------------------------------

## Phase 8 -- Unlisted sharing experience

### Goal

Implement secure link sharing and revocation in the coach interface.

### AI prompt

``` text
Implement the Unlisted assessment sharing experience.

Use the API contract from Phase 5. Do not create a second token-generation mechanism in the frontend.

Requirements:

1. For an Unlisted assessment, show a Share action to users authorized to manage it.
2. Provide Copy Link.
3. Provide WhatsApp sharing using the generated URL and a concise message.
4. Use the Web Share API when supported, with a graceful fallback.
5. Implement Regenerate Link.
6. Before regeneration, show a confirmation explaining that the old link will stop working.
7. After regeneration, display the newly returned URL and provide Copy Link.
8. Do not attempt to retrieve the raw token from the assessment record.
9. Do not persist the raw token in local storage, session storage, analytics, logs or application state beyond what is required to display/copy it.
10. Do not show sharing controls to users without management permission.
11. If visibility changes away from Unlisted, remove the sharing UI and explain that the old link is invalid.
12. Handle API errors, network failures, and unsupported native sharing.
13. Avoid exposing tokens in analytics or third-party tracking.
14. Keep the UI responsive and accessible.

Add tests for:
- Authorized share action.
- Unauthorized share action hidden/denied.
- Copy link.
- WhatsApp link generation.
- Native share fallback.
- Regeneration confirmation.
- Successful regeneration.
- Failed regeneration.
- Old URL is not reused.

Run relevant tests and report results.
```

### Deliverable

Complete Unlisted sharing interface with link revocation.

------------------------------------------------------------------------

## Phase 9 -- Routing, login continuation and listing behavior

### Goal

Connect the new URLs to the frontend and ensure listing behavior matches
visibility.

### AI prompt

``` text
Implement frontend routing and listing behavior for AssessmentSession visibility.

Requirements:

1. Standard route:
   /assessments/:public_slug

2. Unlisted route:
   /assessments/share/:share_token

3. Standard route:
   - Requires login for all visibility levels.
   - Fetches the assessment by public_slug.
   - Lets the API decide whether the user may view it.
   - If an anonymous user opens a Public assessment, redirect to login and return to the original URL after successful authentication.
   - Do not reveal private/internal assessment details before authorization.

4. Unlisted route:
   - Works without login.
   - Fetches through the dedicated share endpoint.
   - Renders only the restricted read-only representation.
   - Does not expose edit, delete, comment, participant-management or administrative controls.
   - Handles invalid/revoked tokens with a neutral not-found/expired-link experience.

5. Listings:
   - Public may appear in approved authenticated discovery/listing areas.
   - Unlisted must never appear in ordinary search, listing, feed or discovery.
   - Internal appears only to qualifying users.
   - Private appears only in authorized coach/admin views and never in player-facing lists.

6. Avoid caching token-bearing routes or responses in shared caches.
7. Add noindex/nofollow metadata to unlisted pages where applicable.
8. Ensure tokens are not sent to analytics or third-party scripts.
9. Preserve existing routes during a planned compatibility period if necessary.

Add route, authentication-continuation, and listing tests. Run frontend checks and report results.
```

### Deliverable

Working slug/share routes, login continuation, and visibility-aware
lists.

------------------------------------------------------------------------

## Phase 10 -- Audit logging

### Goal

Record sensitive visibility and sharing changes without recording
secrets.

### AI prompt

``` text
Implement audit logging for AssessmentSession visibility and sharing operations.

First inspect the existing audit/history mechanism. Reuse it rather than creating a competing system.

Record:
- Visibility changed.
- Sharing token generated.
- Sharing token regenerated.
- Sharing token invalidated when leaving Unlisted.
- Any other approved visibility-management event.

For each event, record the assessment identifier, acting user, event type, previous/new visibility where applicable, and timestamp.

Security requirements:
- Never store the raw share token.
- Never store a URL containing the raw token.
- Do not log token values in Rails logs or exception reporting.
- Ensure ordinary users cannot alter audit records.
- Follow existing retention and access rules.

Add tests for event creation, actor attribution, and absence of raw tokens. Document how administrators can inspect the events.
```

### Deliverable

Auditable visibility and sharing changes.

------------------------------------------------------------------------

## Phase 11 -- Security review and integration testing

### Goal

Validate the complete feature, including direct API access and privilege
escalation attempts.

### AI prompt

``` text
Perform a security-focused integration review of the completed AssessmentSession visibility feature.

Do not assume the implementation is secure because unit tests pass.

Test all combinations of:
- Anonymous visitor.
- Registered user outside the organization.
- Organization member.
- Assigned coach.
- Unassigned coach.
- Involved player.
- Uninvolved player.
- BVBH administrator.

Test all visibility values:
- Public.
- Unlisted.
- Internal.
- Private.

Test:
1. Direct standard slug access.
2. Direct database-ID access through legacy endpoints.
3. Invalid, guessed and revoked share tokens.
4. Token after visibility changes.
5. Token after assessment deletion.
6. Membership removal.
7. Coach assignment removal.
8. Player removal from assessment.
9. Attempts to update, delete, comment, edit scores or manage participants using view-only access.
10. Direct nested-resource endpoint access.
11. Direct media and attachment access.
12. Signed URL expiration and cache behavior.
13. Data leakage in serializers, errors, logs, analytics and exports.
14. Public and unlisted player privacy.
15. Listing/search leakage for Unlisted, Internal and Private sessions.

Run the complete backend and frontend test suites, lint, type checks and relevant security checks.

Produce:
- Security test matrix with pass/fail.
- Any vulnerabilities found.
- Fixes made.
- Remaining limitations, especially signed URL revocation delay.
- Commands and test output summaries.

Do not claim a test passed unless it was actually run.
Do not deploy.
```

### Deliverable

Security test report and resolved findings.

------------------------------------------------------------------------

## Phase 12 -- Documentation and production deployment preparation

### Goal

Prepare a controlled production release.

### AI prompt

``` text
Prepare the AssessmentSession visibility feature for production deployment.

Do not deploy or run the production migration.

Tasks:
1. Update API documentation and frontend documentation.
2. Document visibility meanings and the permission matrix.
3. Document standard slug and unlisted share URL behavior.
4. Document token generation, digest storage and revocation.
5. Document nested-resource and media authorization.
6. Document audit events.
7. Review migration safety and expected production impact.
8. Confirm the migration is compatible with the production PostgreSQL version.
9. Confirm existing sessions receive the intended conservative visibility.
10. Prepare a deployment sequence for API and frontend.
11. Prepare smoke tests for production after release.
12. Document rollback considerations. Do not assume a destructive down migration is safe after new records have been created.
13. Identify any environment variables or storage configuration changes. Do not invent new variables if not required.
14. Verify no secrets or raw tokens are present in committed files.

Return:
- Deployment checklist.
- Migration command(s).
- API/frontend deployment order.
- Smoke-test checklist.
- Rollback plan and limitations.
- Final list of changed files.
- Outstanding risks.

Do not deploy, migrate production, or modify live infrastructure.
```

### Deliverable

Release documentation and deployment checklist.

------------------------------------------------------------------------

## Phase 13 -- Production release and verification

### Goal

Deploy in a controlled sequence after explicit owner approval.

### AI prompt

``` text
We have approved the AssessmentSession visibility implementation for production release.

Before taking any action:
1. Confirm the current production deployment targets and branches.
2. Confirm the API and frontend changes are committed and pushed to the intended branches.
3. Confirm CI and all required tests pass.
4. Confirm the production database backup/restore procedure and migration plan.
5. Confirm the migration has been reviewed.
6. Present the exact deployment and migration commands and wait for explicit approval.

After approval, follow the approved deployment sequence.

Post-deployment:
- Verify the migration completed.
- Verify existing assessment sessions have slugs and the intended visibility.
- Verify new sessions default to Internal.
- Verify public access requires login.
- Verify unlisted access works without login.
- Verify link regeneration invalidates the previous token.
- Verify internal and private permissions.
- Verify player and coach dashboards.
- Verify media and attachment protections.
- Verify logs do not contain raw tokens.
- Record deployment time, commit SHAs, migration status and smoke-test results.

Do not perform destructive rollback or database changes without explicit approval.
```

### Deliverable

Production deployment record and smoke-test results.

------------------------------------------------------------------------

# 8. Cross-phase acceptance criteria

The feature is complete only when all applicable items pass.

## Data and model

-   [ ] New sessions default to `internal`.
-   [ ] All four enum values are supported.
-   [ ] Every session has a unique stable slug.
-   [ ] Slugs do not expose sequential database IDs.
-   [ ] Share tokens are cryptographically secure.
-   [ ] Only token digests are stored.
-   [ ] Token regeneration invalidates the old token.
-   [ ] Leaving Unlisted invalidates the active token.

## Authorization

-   [ ] Public requires authentication and allows every registered user
    to view.
-   [ ] Unlisted allows read-only access with a valid link and no login.
-   [ ] Internal allows qualifying organization members, assigned
    coaches and involved players.
-   [ ] Private allows only authorized coaches and BVBH administrators.
-   [ ] View permission does not imply edit/delete permission.
-   [ ] Membership and assignment removal revoke access.
-   [ ] Every nested resource checks parent authorization.

## Privacy and media

-   [ ] Public/unlisted representations exclude private player
    information.
-   [ ] Internal notes are not exposed to public/unlisted viewers.
-   [ ] Protected media URLs cannot bypass authorization.
-   [ ] Signed URLs have documented expiry.
-   [ ] Token-bearing responses are not publicly cached.
-   [ ] Raw tokens are absent from logs, analytics and audit events.

## Frontend

-   [ ] Visibility selector is present in create/edit UI.
-   [ ] Internal is selected by default.
-   [ ] Visibility descriptions and indicators are consistent.
-   [ ] Unlisted sharing supports copy, WhatsApp and native sharing
    where available.
-   [ ] Regeneration requires confirmation.
-   [ ] Old links fail after regeneration.
-   [ ] Anonymous Public visitors are redirected to login.
-   [ ] Unlisted sessions do not appear in ordinary listings.
-   [ ] Private sessions do not appear in player dashboards.

## Quality and release

-   [ ] Backend tests pass.
-   [ ] Frontend tests pass.
-   [ ] Lint and type checks pass.
-   [ ] Security integration tests pass.
-   [ ] API and frontend documentation are updated.
-   [ ] Production migration is reviewed.
-   [ ] Deployment smoke tests pass.

------------------------------------------------------------------------

# 9. Out of scope for the first release

Do not implement these unless separately approved:

-   Multiple active sharing links per assessment.
-   Expiring sharing links.
-   Password-protected links.
-   Individual external-user invitations.
-   Custom permissions per player.
-   External coach collaboration.
-   Advanced access analytics.
-   Approval workflows for Public assessments.
-   Per-video sharing permissions.

A future external-coach invitation feature should be a separate
authorization mechanism, not a fifth visibility value.

------------------------------------------------------------------------

# 10. Recommended execution workflow

1.  Open the API and frontend repositories in the coding environment.
2.  Run Phase 0 and confirm the correct workspace.
3.  Run Phase 1 and review the architecture report.
4.  Resolve domain and permission ambiguities in Phase 2.
5.  Execute one implementation phase at a time.
6.  Review the diff and test results after every phase.
7.  Do not allow the AI tool to silently skip tests or change unrelated
    architecture.
8.  Commit logical, reviewed changes in small increments.
9.  Complete the security review before production preparation.
10. Deploy only after reviewing the migration and receiving explicit
    approval.

## Final architectural direction

Keep `visibility` as a property of `AssessmentSession`.

Use: - `public_slug` for stable resource identification. -
`share_token_digest` for revocable Unlisted access. - Centralized policy
authorization for authenticated access. - A dedicated read-only sharing
path for Unlisted access. - Parent-resource authorization for all nested
records and media.

This delivers the four requested visibility levels without coupling
access control to database IDs or frontend presentation, and leaves room
for future external collaboration features.
