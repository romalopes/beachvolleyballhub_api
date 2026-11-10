# BeachVolleyballHub --- API Abuse and HTTP 429 Protection Plan

**Project:** BeachVolleyballHub\
**API repository:** `romalopes/beachvolleyballhub_api`\
**Frontend repository:** `romalopes/beachvolleyballhub_frontend`\
**Primary API deployment:** Render, Docker, `main` branch (verify
current service and hostname before implementation)\
**Target API domain:** `api.beachvolleyballhub.com` (verify current DNS
and deployment)\
**Document type:** Security implementation plan\
**Priority:** High --- API availability, account protection, and
resource-abuse prevention\
**Status:** Proposed; source-level audit required before implementation

------------------------------------------------------------------------

## 1. Executive summary

BeachVolleyballHub is a Rails API with a React/Vite frontend. The
platform includes public discovery and location functionality, accounts
and memberships, player and coach profiles, organisations, training
sessions, tournaments, assessments, analysis, media, and notifications.

These features create several different abuse surfaces:

-   Automated request floods against public API endpoints.
-   Brute-force login, registration, and password-reset attempts.
-   Scraping of public organisation, location, profile, tournament, and
    training information.
-   Excessive or automated geospatial searches against
    nearby-organisation and map endpoints.
-   Spam submissions for proposed locations, invitations, comments, or
    other user-generated content.
-   Abuse of video, image, and file upload endpoints.
-   Expensive analysis, assessment, weather, or other external-service
    operations.
-   Unauthorized access attempts against account-scoped records and
    media.
-   Notification and email flooding.
-   Traffic that bypasses Cloudflare and reaches the Render origin
    directly.

HTTP 429 (`Too Many Requests`) is a response status commonly returned
when a client exceeds a rate limit. It is not the attack itself. The
goal is to reject abusive traffic early, preserve service availability,
protect infrastructure and external-service quotas, and avoid blocking
legitimate coaches, players, organisations, and public visitors.

**Important audit limitation:** The public GitHub repository pages were
identifiable, but complete source-file inspection was not available
during preparation of this plan. Therefore, this document does not claim
that Rack::Attack, a particular cache backend, Cloudflare WAF, or any
specific throttle already exists in BeachVolleyballHub. Phase 0 must
verify the current implementation and deployment before code changes.

### Target architecture

1.  **Cloudflare edge protection** --- filter or challenge abusive
    traffic before it reaches Render, using features actually available
    on the current account plan.
2.  **Rails API protection** --- apply route-aware and identity-aware
    throttling, validation, authorization, and resource limits.
3.  **Shared rate-limit storage** --- use a counter store that works
    across all API processes and instances.
4.  **Resource and business-operation protection** --- control expensive
    queries, geospatial searches, uploads, background jobs,
    notifications, and external APIs.
5.  **Monitoring and incident response** --- detect traffic spikes,
    repeated 429 responses, origin bypass attempts, and resource
    saturation.
6.  **Automated tests and staged rollout** --- prove that the controls
    work without breaking normal app usage.

------------------------------------------------------------------------

## 2. Project-specific architecture and domain assumptions to verify

Use these known project details as audit context, but verify them
against the current repositories and deployment before implementation:

-   Rails API and React/Vite frontend.
-   Rails 8.1.3 and Ruby 3.4.2 have been used in the project context;
    verify current versions from the repository and deployed image.
-   Render is used for API hosting with Docker.
-   The current API repository is `romalopes/beachvolleyballhub_api`.
-   The current frontend repository is
    `romalopes/beachvolleyballhub_frontend`.
-   The intended public domain architecture uses Cloudflare for the
    frontend and `api.beachvolleyballhub.com` for the API.
-   Public Home/map functionality can resolve a map target using browser
    geolocation, IP fallback, a Coogee fallback, or coordinates returned
    from a weather/location search.
-   Public nearby-organisation discovery is intended to use latitude,
    longitude, radius, and limit, returning active organisations with
    active, verified default locations and coordinates.
-   Organisation management is authenticated.
-   Users may propose locations; Admin/Curator workflows manage
    verification or rejection.
-   The platform has account membership, roles/permissions, player and
    coach profiles, training sessions, tournaments, assessments,
    analysis, and media functionality.
-   Analysis can involve video URLs or uploads, multiple players,
    comments, and assessment links.
-   Notification functionality is planned or being developed.

These features are relevant to abuse prevention because a public read
endpoint, an authenticated write endpoint, a media upload, and an
expensive external-service call need different controls.

------------------------------------------------------------------------

## 3. Goals

-   Protect API availability against request floods and abusive
    automation.
-   Protect login, registration, account recovery, and invitation flows.
-   Prevent unauthenticated scraping from consuming excessive database
    and application resources.
-   Protect public map and nearby-organisation searches from excessive
    or pathological queries.
-   Protect user-generated content and location-submission workflows
    from spam.
-   Protect video, image, and file uploads from storage exhaustion and
    processing floods.
-   Protect account-scoped operations from enumeration and unauthorized
    access attempts.
-   Protect notification, email, weather, and other external-service
    quotas.
-   Apply limits consistently across all Rails processes and instances.
-   Return a documented HTTP 429 response with a meaningful retry
    interval where possible.
-   Preserve normal use by players, coaches, organisation
    administrators, and public visitors.
-   Prefer existing infrastructure and free or low-cost controls where
    practical.
-   Make abuse observable without logging credentials, tokens, or
    unnecessary personal information.

## 4. Non-goals

This project does not aim to:

-   Guarantee immunity from every DDoS attack.
-   Replace authentication, authorization, input validation, or secure
    file handling.
-   Block all automated clients or legitimate search-engine crawlers
    without a policy decision.
-   Treat every HTTP 429 as evidence of a malicious attack.
-   Introduce Redis or another paid service by default.
-   Expose precise user location or movement history for security
    monitoring.
-   Change product entitlements or introduce user-facing quotas without
    a separate product decision.

------------------------------------------------------------------------

## 5. Phase 0 --- Audit the current API and production architecture

### Objectives

Establish exactly what protections exist today, which endpoints are
exposed, and how requests reach the Rails API.

### API repository audit

Inspect:

1.  `Gemfile` and lockfile:
    -   `rack-attack` and version, if present.
    -   Cache gems and adapters.
    -   Authentication gems and implementation.
    -   Upload/Active Storage gems and storage services.
    -   Background-job adapter.
    -   Error monitoring and logging.
2.  `config/application.rb`:
    -   Middleware stack and middleware ordering.
3.  `config/initializers/`:
    -   Rack::Attack, CORS, authentication, storage, and
        security-related initializers.
4.  `config/routes.rb`:
    -   All public and authenticated API routes.
    -   Authentication, registration, password reset, invitation, and
        account routes.
    -   Public organisation and nearby-location endpoints.
    -   Location proposal and verification endpoints.
    -   Training, tournament, assessment, analysis, comment, and
        notification routes.
    -   Upload and media routes.
5.  Controllers, policies, services, and jobs:
    -   Authentication and account scoping.
    -   Role and permission checks.
    -   Geospatial queries and pagination.
    -   Upload processing and background jobs.
    -   Email, notification, weather, and external API calls.
6.  Tests:
    -   Existing request specs, controller specs, policy specs, and
        security tests.
7.  Deployment:
    -   Render service configuration and Docker setup.
    -   Production environment variables and cache configuration.
    -   Number of web processes/instances and any worker services.
    -   Health-check route and monitoring configuration.

### Frontend repository audit

Inspect:

-   API client and base URL configuration.
-   Authentication token/session handling.
-   Request retry logic.
-   Whether 429 responses trigger automatic retries.
-   Whether the client respects `Retry-After`.
-   Map and nearby-organisation request frequency.
-   Browser geolocation and IP-fallback behaviour.
-   Search debounce and pagination.
-   Upload retry behaviour and duplicate submissions.
-   Notification polling or refresh behaviour.
-   Any public API calls made before login.

### Cloudflare and Render audit

Confirm:

-   The actual API production hostname.
-   Whether the API DNS record is proxied through Cloudflare.
-   Whether Cloudflare WAF and rate-limiting features are available on
    the active plan.
-   Whether the Render `onrender.com` hostname can be accessed directly.
-   Whether there are staging, preview, or alternate origin hostnames.
-   Whether the application trusts forwarded IP headers safely.
-   Whether origin access can be restricted or verified.
-   Which Cloudflare headers (for example, Ray ID) are available to
    logs.

### Deliverables

-   Production request-flow diagram.
-   Current protection inventory.
-   Complete route inventory classified by risk.
-   Current cache and rate-limit storage assessment.
-   Cloudflare/Render origin exposure assessment.
-   Frontend retry and request-frequency assessment.
-   Prioritized gap analysis.

### AI implementation prompt

> Audit both BeachVolleyballHub repositories:
>
> -   `romalopes/beachvolleyballhub_api`
> -   `romalopes/beachvolleyballhub_frontend`
>
> Also review the actual Render and Cloudflare deployment configuration
> available in the repository or supplied environment documentation.
>
> This is an audit only. Do not modify files.
>
> Inspect the real Rails routes, middleware, Gemfile, lockfile,
> initializers, controllers, policies, services, jobs, upload
> configuration, cache configuration, and tests. Inspect the frontend
> API client, authentication handling, map requests, geolocation
> fallbacks, retries, uploads, and notification polling.
>
> Pay special attention to public nearby-organisation and location
> endpoints; account and role/permission boundaries; location proposals;
> training sessions; tournaments; assessments; analysis/video; comments;
> notifications; uploads; and external-service calls.
>
> Determine whether Rack::Attack is installed and configured. If it is
> present, list every actual throttle and its storage backend. If it is
> absent, say so. Do not infer that a gem or protection exists from this
> plan.
>
> Determine whether rate-limit counters are shared across all production
> processes and instances. Check whether the API is behind Cloudflare
> and whether the Render origin can be accessed directly.
>
> Produce a factual report with file paths, route names, current
> protections, missing protections, and recommended priorities. Do not
> invent routes, endpoint paths, deployment settings, or existing
> infrastructure.

------------------------------------------------------------------------

## 6. Phase 1 --- Build the endpoint risk matrix and approve limits

### Objectives

Choose limits based on endpoint risk, resource cost, authentication, and
expected legitimate traffic.

The values below are initial proposals for testing, not final production
thresholds. Confirm actual routes and normal traffic before applying
them.

### Initial policy matrix

  -----------------------------------------------------------------------------------
  Functionality                          Initial proposed limit Suggested
                                                                discriminator
  -------------------------------- ---------------------------- ---------------------
  General public API reads                           120/minute IP

  Login attempts                                   10/5 minutes IP, plus careful
                                                                account-aware
                                                                controls

  Registration                                           5/hour IP

  Password reset                                         5/hour IP and carefully
                                                                designed account
                                                                safeguards

  Public organisation discovery                       60/minute IP

  Nearby-organisation/geospatial                      30/minute IP, plus query-cost
  search                                                        controls

  Public location lookup/search                       30/minute IP

  Location proposals                                     5/hour Authenticated user;
                                                                additional IP limit

  Organisation creation/update                          20/hour Authenticated user
                                                                and account

  Training session creation/update                      30/hour Authenticated
                                                                user/account

  Tournament creation/update                            20/hour Authenticated
                                                                user/account

  Assessment creation/update                            30/hour Authenticated
                                                                user/account

  Analysis creation                                     10/hour Authenticated
                                                                user/account

  Comments                                            20/minute Authenticated user

  Notification actions                                60/minute Authenticated user

  Upload initiation                                     10/hour Authenticated
                                                                user/account

  Public map/weather lookup                           30/minute IP/user, subject to
                                                                provider quota
  -----------------------------------------------------------------------------------

These values should be adjusted based on normal coaching workflows. For
example, a coach may legitimately create several training sessions while
planning a season. Do not use a limit that makes ordinary bulk planning
impossible.

### Policy design principles

-   Use IP-based limits for anonymous requests.
-   Use authenticated user IDs for user-generated writes.
-   Add account-level limits for operations that consume shared
    organisation resources.
-   Use both IP and user limits for sensitive operations where
    appropriate.
-   Do not use a client-supplied user ID as an identity discriminator.
-   Do not rely on IP alone for authenticated users; clubs, schools,
    workplaces, and public Wi-Fi may share an IP.
-   Avoid account-lockout denial-of-service vulnerabilities.
-   Add separate short-burst and sustained limits for high-cost
    endpoints.
-   Exclude or separately configure health checks and trusted internal
    service calls.
-   Do not trust arbitrary `X-Forwarded-For` values. Derive the client
    IP using the actual trusted proxy chain.
-   Keep the policy configurable through well-documented settings.
-   Use endpoint-specific limits rather than a single aggressive global
    limit.

### AI implementation prompt

> Using the Phase 0 audit, create an endpoint-by-endpoint abuse-risk
> matrix for BeachVolleyballHub.
>
> Classify each actual route by public/authenticated access, resource
> cost, business impact, and likely normal usage. Cover authentication,
> public organisation discovery, geospatial searches, location lookup
> and proposals, organisation management, training sessions,
> tournaments, assessments, analysis, comments, notifications, and
> uploads.
>
> Review the initial policy matrix in this document and revise limits
> based on actual routes and expected user workflows.
>
> Include IP, user, and account-level discriminators where appropriate.
> Avoid account-lockout denial-of-service vulnerabilities and unfair
> blocking of users behind shared IP addresses.
>
> Identify routes that need burst limits, sustained limits, payload
> limits, or business-level quotas.
>
> Produce a final policy table and rationale. Do not implement the
> throttles yet.

------------------------------------------------------------------------

## 7. Phase 2 --- Select and configure shared rate-limit storage

### Objectives

Make counters reliable across every production Rails process and
instance.

### Tasks

1.  Inspect the current Rails cache configuration.
2.  Determine whether Solid Cache is installed and configured.
3.  Determine whether Redis or another shared cache is already
    available.
4.  Verify that the selected backend supports the increment and expiry
    semantics required by the installed Rack::Attack version.
5.  Verify atomic behaviour under concurrent requests.
6.  Verify that separate Render processes and instances share counters.
7.  Namespace rate-limit keys and ensure they expire.
8.  Define behaviour when the store is unavailable.
9.  Monitor cache latency and errors.

### Preferred approach

Use an existing shared cache if it is reliable and appropriate for
high-frequency counter updates. Do not assume that a cache is suitable
simply because it is installed.

If Solid Cache is present, verify its atomic increment and concurrency
semantics for the exact Rails and Rack::Attack versions. If it is not
appropriate, evaluate a shared Redis service or another compatible
backend. Consider the operational cost and resilience impact before
adding a service.

Do not use process-local `MemoryStore` as the production shared counter
store when multiple processes or instances must enforce the same limit.

### Failure behaviour

Document and test:

-   What happens if the rate-limit store is slow or unavailable.
-   Whether sensitive authentication endpoints use conservative fallback
    protection.
-   Whether non-sensitive reads can continue temporarily.
-   How failures are logged and alerted.
-   How the application recovers when the store returns.

Do not allow a cache outage to silently disable every important abuse
control.

### AI implementation prompt

> Implement reliable shared rate-limit storage for BeachVolleyballHub
> after inspecting the actual production cache and deployment
> configuration.
>
> Inspect the installed Rack::Attack and Rails versions, if Rack::Attack
> is present or selected. Verify the selected store's atomic increment
> and expiry behaviour under concurrency and across multiple application
> processes.
>
> Prefer existing shared infrastructure if it meets the requirements.
> Evaluate Solid Cache only if it is actually installed/configured. Do
> not add Redis unless the existing infrastructure is unsuitable and the
> trade-off is documented.
>
> Remove any process-local-only production counter configuration. Add
> tests for independent clients/processes, concurrency, expiry, and
> cache failure.
>
> Document the fallback behaviour and operational implications. Do not
> claim multi-process protection based on a single-process test.

------------------------------------------------------------------------

## 8. Phase 3 --- Implement Rails API throttling

### Objectives

Protect the API at the application layer with route-aware and
identity-aware limits.

### Tasks

1.  Use the existing Rack::Attack integration if present and
    appropriate; otherwise add and configure it after confirming
    compatibility.
2.  Place throttling early in the request lifecycle.
3.  Add named throttles based on the approved policy.
4.  Use safe IP identification.
5.  Use authenticated user identity for user-specific operations.
6.  Use account identity for operations that consume shared organisation
    resources.
7.  Protect anonymous endpoints separately from authenticated
    operations.
8.  Keep health checks and required internal calls functional.
9.  Return a consistent JSON 429 response.
10. Add `Retry-After` where the configured throttle can calculate a
    meaningful value.
11. Ensure throttled requests do not reach expensive controller actions
    or trigger side effects.
12. Avoid logging credentials, tokens, or sensitive request bodies.

### Endpoint groups to cover after confirming actual routes

#### Authentication

-   Login.
-   Registration.
-   Password recovery.
-   Password reset completion.
-   Invitation acceptance.
-   Any account-claim or profile-claim flow.

Use IP throttles and carefully designed account-aware controls. Do not
let an attacker easily lock out another user's account by deliberately
exhausting an email-specific limit.

#### Public discovery and location

-   Public organisation list/discovery.
-   Nearby-organisation search.
-   Location search and lookup.
-   Public map-related API calls.
-   Public profile or event reads, if exposed.

Apply conservative IP limits, pagination limits, maximum radius,
coordinate validation, and query-cost safeguards.

#### Organisation and account operations

-   Organisation creation and updates.
-   Membership and invitation operations.
-   Role/permission changes.
-   Account/profile claim workflows.
-   Location verification or moderation operations.

Apply authenticated user and account-level controls, with authorization
enforced independently of throttling.

#### Volleyball operations

-   Training session creation and updates.
-   Recurring training templates.
-   Tournament creation and updates.
-   Assessment creation and updates.
-   Analysis creation and comments.
-   Player/coach profile updates.

Use per-user and per-account limits appropriate to legitimate coaching
and administration workflows.

#### Notifications and communication

-   Notification creation or triggering.
-   Email-triggering actions.
-   Invitation messages.
-   Comment and mention notifications.

Prevent notification floods and repeated email delivery.

#### Uploads and media

-   Upload initiation.
-   Direct-upload authorization.
-   Attachment creation.
-   Video/image processing triggers.
-   Media deletion or replacement.

Apply upload-specific limits and file-size controls, not just generic
request limits.

### Suggested response contract

Follow the API's existing error response conventions. If there is no
consistent format, agree on a response such as:

``` json
{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "Too many requests. Please try again later."
  }
}
```

Return HTTP 429. Include `Retry-After` when meaningful. Do not expose
internal throttle keys, secrets, or implementation details.

### AI implementation prompt

> Implement the approved rate-limiting policy in the BeachVolleyballHub
> Rails API.
>
> Use the actual route paths, HTTP methods, authentication mechanisms,
> and account model found in the repository. Do not invent endpoints.
>
> Reuse the existing Rack::Attack setup if present and sound. If it is
> absent, propose and add it with a compatible version and tests.
>
> Implement named throttles for authentication, public discovery,
> nearby-organisation/geospatial search, location lookup and proposals,
> organisation/account operations, training, tournaments, assessments,
> analysis, comments, notifications, and uploads as applicable to actual
> routes.
>
> Use IP, authenticated user, and account discriminators appropriately.
> Derive identity from trusted server-side authentication state, not
> client-supplied IDs.
>
> Preserve normal coach and organisation workflows. Avoid
> account-lockout denial-of-service vulnerabilities.
>
> Return the API's standard JSON error contract with HTTP 429 and a
> meaningful Retry-After header where possible. Ensure rejected requests
> do not perform database writes, send emails, enqueue jobs, or trigger
> external calls.
>
> Add focused middleware and request tests. Document every throttle and
> its rationale.

------------------------------------------------------------------------

## 9. Phase 4 --- Protect public geospatial and discovery endpoints

### Objectives

Prevent public map and nearby-organisation functionality from becoming
an expensive query or scraping attack surface.

This phase is particularly important because BeachVolleyballHub has
public map/discovery functionality that can be used before login.

### Tasks

1.  Confirm all public geospatial and location endpoints.
2.  Validate latitude and longitude ranges.
3.  Enforce a sensible maximum radius.
4.  Enforce a sensible maximum result limit.
5.  Require pagination or bounded results where appropriate.
6.  Ensure the database uses appropriate indexes for the actual
    geospatial/distance query approach.
7.  Avoid unbounded full-table scans.
8.  Reject malformed, missing, or extreme coordinate/radius
    combinations.
9.  Apply IP-based throttles to anonymous map and discovery requests.
10. Consider short-lived caching for repeated, safe public queries.
11. Avoid caching private or authorization-dependent data in a public
    cache.
12. Avoid returning more precise location information than the product
    requires.
13. Monitor query duration and database load.
14. Ensure the frontend debounces search and does not issue duplicate
    requests during map movement or rerendering.

### Location privacy

The app may use browser geolocation, IP fallback, a default map target,
or coordinates from a submitted search. These sources have different
precision and reliability.

For security monitoring, prefer coarse aggregation and minimal
retention. Do not turn rate-limit logs into a history of individual
users' precise movements. Do not store precise geolocation for abuse
analytics unless there is a separately justified product/security
requirement and an explicit privacy review.

### AI implementation prompt

> Audit and harden BeachVolleyballHub's public geospatial and location
> endpoints.
>
> Find the actual nearby-organisation, public map, location search, and
> public location routes and inspect their query implementation.
>
> Verify latitude/longitude validation, maximum radius, result limits,
> pagination, database indexes, query plans, caching, and authorization
> behaviour.
>
> Implement bounded inputs and safe query limits. Add anonymous IP
> throttling and any additional controls justified by measured query
> cost.
>
> Review the frontend map and discovery request patterns for debouncing,
> duplicate calls, retries, and cancellation of obsolete requests.
>
> Preserve the intended public map experience. Do not collect or retain
> precise user movement history for security monitoring. Use only the
> minimum location detail necessary.
>
> Add request, service, and performance tests for normal and
> pathological inputs.

------------------------------------------------------------------------

## 10. Phase 5 --- Protect uploads, video, and background processing

### Objectives

Prevent media uploads and asynchronous processing from exhausting
storage, CPU, memory, or job capacity.

### Tasks

Inspect the actual Active Storage or upload implementation and determine
whether files are stored locally, on Cloudflare R2, or another service.

Protect:

-   Upload authorization.
-   Maximum file size.
-   Allowed content types and file extensions.
-   Actual file signature/content validation.
-   Video duration and resolution where applicable.
-   Number of uploads per user/account and time period.
-   Duplicate or repeated upload requests.
-   Image/video processing concurrency.
-   Background job retries and dead-letter handling.
-   Attachment ownership and access control.
-   Signed upload URL expiry and scope.
-   Storage quotas and cleanup of abandoned uploads.

For analysis videos and other media:

-   Do not allow arbitrary unauthenticated upload initiation.
-   Verify that the requesting user is authorized to attach media to the
    target analysis or account.
-   Ensure a user cannot attach or retrieve another account's media by
    changing an ID.
-   Apply separate limits to upload initiation and processing jobs.
-   Avoid reprocessing the same attachment repeatedly.

### AI implementation prompt

> Audit and harden BeachVolleyballHub's media and upload pipeline.
>
> Inspect the actual upload routes, Active Storage configuration,
> storage provider, direct-upload flow, signed URLs, analysis/video
> attachment relationships, image processing, background jobs, and
> authorization policies.
>
> Implement appropriate maximum file sizes, allowed content types,
> content validation, per-user/account upload limits, signed URL expiry,
> ownership checks, processing concurrency controls, and retry
> safeguards.
>
> Ensure a user cannot attach, view, replace, or delete another user's
> or account's media by manipulating record IDs.
>
> Add tests for oversized files, invalid content, unauthorized
> attachments, repeated upload initiation, duplicate processing, and job
> failure.
>
> Do not assume Cloudflare R2 is already configured; verify the actual
> storage service first.

------------------------------------------------------------------------

## 11. Phase 6 --- Protect notifications, email, weather, and external services

### Objectives

Prevent abuse from consuming external quotas or generating excessive
jobs and messages.

### Tasks

Inspect all actions that can trigger:

-   Email delivery.
-   Invitation emails.
-   Password-reset emails.
-   Notification creation.
-   Push notifications, if implemented.
-   Weather API calls.
-   Geocoding or map-related services.
-   Video/media processing providers.
-   Any other third-party APIs.

Implement:

1.  Per-user and per-account action limits.
2.  Per-IP limits for public triggers.
3.  Deduplication or idempotency where retries can repeat an action.
4.  Queue concurrency limits for expensive jobs.
5.  Exponential backoff for transient provider failures.
6.  Maximum retry counts and dead-letter handling.
7.  Provider quota monitoring.
8.  Caching for safe repeatable external lookups.
9.  Protection against repeatedly notifying the same recipients for the
    same event.
10. Authorization checks before enqueuing jobs.

Do not make a request to an external provider before validating
authorization and applying relevant limits.

### AI implementation prompt

> Audit BeachVolleyballHub for abuse paths that trigger email,
> notifications, weather, geocoding, media processing, or other external
> services.
>
> Identify the actual controllers, services, jobs, and provider
> integrations. Map each trigger to its cost and abuse risk.
>
> Implement appropriate user/account/IP limits, deduplication,
> idempotency, job concurrency, retry limits, backoff, and provider
> quota monitoring.
>
> Ensure unauthorized or throttled requests cannot enqueue jobs or call
> external services.
>
> Preserve legitimate notification behaviour and avoid duplicate
> messages caused by retries. Add tests for repeated triggers, job
> failures, and quota-related errors.

------------------------------------------------------------------------

## 12. Phase 7 --- Review authorization and resource enumeration

### Objectives

Ensure abuse controls are complemented by strong account and
object-level authorization.

Rate limiting does not prevent a user from accessing records they are
not authorized to see.

### Areas to audit

-   Account membership and role permissions.
-   Organisation ownership and administration.
-   Coach/player profile creation and claims.
-   Invitations and membership acceptance.
-   Location creation, proposal, verification, and moderation.
-   Training session and tournament ownership.
-   Assessment and analysis access.
-   Player associations with analysis.
-   Comments and attachments.
-   Notification visibility.
-   Signed media URLs and attachment downloads.

### Tasks

-   Verify every record lookup is scoped to the authenticated account or
    authorized relationship.
-   Check policies and service-layer authorization, not only frontend
    visibility.
-   Prevent ID enumeration from revealing private records.
-   Use consistent not-found/forbidden behaviour where appropriate.
-   Test cross-account access attempts.
-   Avoid leaking sensitive account or profile information in error
    messages.
-   Add audit logging for sensitive role, membership, and moderation
    changes.

### AI implementation prompt

> Perform an authorization and object-enumeration audit of
> BeachVolleyballHub.
>
> Inspect account membership, roles/permissions, organisation ownership,
> profile claims, invitations, locations, training sessions,
> tournaments, assessments, analysis, comments, notifications, and
> media.
>
> Identify endpoints where a user could access or modify another
> account's records by changing an ID, relationship, or request
> parameter.
>
> Verify authorization in the Rails API, not merely in frontend route
> guards. Add policy/request tests for authorized and unauthorized
> cross-account access.
>
> Check for enumeration through response codes, error messages, and
> public serializers. Do not change legitimate public discovery
> behaviour without a documented reason.
>
> Report and fix confirmed vulnerabilities with focused tests.

------------------------------------------------------------------------

## 13. Phase 8 --- Cloudflare edge protection and Render origin security

### Objectives

Stop abusive traffic before it consumes Render application resources.

### Cloudflare tasks

1.  Confirm the API hostname and DNS proxy status.
2.  Verify the active Cloudflare plan and the features available to this
    zone.
3.  Configure API-specific rate limits.
4.  Add narrower controls for login, registration, password recovery,
    public discovery, and other high-risk routes where supported.
5.  Use managed challenges only where appropriate for browser traffic.
6.  Avoid interactive challenges that break API clients, PWA clients, or
    future Capacitor clients.
7.  Monitor Cloudflare actions and Ray IDs.
8.  Test normal traffic and known legitimate API clients.
9.  Keep edge limits complementary to Rails limits.

### Render origin tasks

A Cloudflare-proxied hostname does not necessarily prevent direct access
to the Render default hostname.

1.  Confirm whether the Render origin hostname is publicly reachable.
2.  Review Render's supported network and inbound access controls.
3.  Investigate a supported origin-verification mechanism.
4.  If using a secret header:
    -   Keep the secret on the server only.
    -   Never put it in frontend JavaScript or public configuration.
    -   Verify it before expensive application processing.
    -   Rotate it safely.
    -   Understand that it is an application-layer control, not a
        network firewall.
5.  Test the custom API hostname and the Render origin hostname
    separately.
6.  Document any origin exposure that cannot be eliminated on the
    current hosting plan.

### Suggested edge policy to evaluate

  Traffic                          Initial approach
  -------------------------------- --------------------------------------
  General API traffic              Conservative rate limit
  Authentication endpoints         Tighter route-specific limits
  Public discovery/map endpoints   Route-specific rate limits
  Upload initiation                Tight limit and body-size controls
  Obvious abusive automation       Challenge or block based on evidence
  Normal PWA/API clients           Allow without browser-only challenge
  Health checks                    Explicitly preserve monitoring

Cloudflare feature availability and rule limits depend on the current
plan and configuration. Verify before promising a particular rule or
capability.

### AI implementation prompt

> Design and configure Cloudflare protection for the actual
> BeachVolleyballHub API hostname.
>
> Verify DNS proxy status, Cloudflare plan, available WAF/rate-limiting
> capabilities, Render origin hostname, and all alternate paths to the
> API.
>
> Propose rules for general API traffic, authentication, public
> discovery/map endpoints, and upload initiation. Ensure normal browser,
> PWA, and future Capacitor API clients are not broken by interactive
> browser challenges.
>
> Investigate whether the Render origin can be reached directly.
> Recommend a supported origin-protection approach and document
> limitations. Never place origin secrets in frontend code.
>
> Provide exact dashboard steps, rule expressions, validation tests, and
> rollback steps. Do not claim that Cloudflare Workers frontend hosting
> automatically protects the API.

------------------------------------------------------------------------

## 14. Phase 9 --- Frontend behaviour for HTTP 429 and request efficiency

### Objectives

Ensure the frontend behaves responsibly when the API throttles a client.

### Tasks

Inspect and improve the shared API client:

-   Detect HTTP 429 responses.
-   Respect `Retry-After`.
-   Avoid immediate retry loops.
-   Use bounded exponential backoff with jitter for safe retryable
    operations.
-   Do not automatically retry non-idempotent writes unless the
    operation has an idempotency strategy.
-   Display a clear, non-technical message to the user.
-   Preserve form data when a request is throttled.
-   Avoid duplicate submissions caused by repeated button clicks.
-   Cancel obsolete search/map requests where possible.
-   Debounce search and map movement.
-   Ensure polling and notification refresh intervals are sensible.
-   Avoid retrying failed requests indefinitely while the app is in the
    background.

### AI implementation prompt

> Review the BeachVolleyballHub frontend API client and all request
> patterns.
>
> Implement consistent handling for HTTP 429 using Retry-After when
> present. Add bounded exponential backoff with jitter only for safe
> retryable requests. Do not automatically retry non-idempotent writes
> without idempotency protection.
>
> Prevent duplicate form submissions and preserve user input when
> throttled. Review map/geospatial search, autocomplete, notification
> refresh, and polling for excessive request frequency.
>
> Ensure the frontend communicates throttling clearly without exposing
> technical details. Test browser and PWA behaviour, and keep the API
> client compatible with future Capacitor clients.

------------------------------------------------------------------------

## 15. Phase 10 --- Monitoring, logging, and alerting

### Objectives

Distinguish attacks from normal traffic, frontend bugs, and
misconfigured clients.

### Metrics to collect

-   Total API requests and request rate by route/method.
-   HTTP 429 count and percentage.
-   HTTP 5xx rate.
-   Request latency.
-   Throttle rule name.
-   Client IP information, protected and retained appropriately.
-   Authenticated user/account identifier where justified.
-   Cloudflare action and Ray ID where available.
-   Geospatial query duration and result counts.
-   Upload initiation volume and processing queue depth.
-   Notification/email job volume.
-   External provider errors and quota consumption.
-   Database connection saturation and slow queries.
-   Cache/rate-limit-store latency and failures.
-   Background job retries and queue delays.

### Privacy and location-specific logging

BeachVolleyballHub can use browser geolocation and coordinates for map
discovery. Security telemetry should not become a record of individual
users' movements.

-   Prefer coarse geographic aggregation for product analytics.
-   Do not log precise coordinates by default in abuse logs.
-   Avoid storing full location request payloads.
-   Keep security logs access-controlled and time-limited.
-   Separate operational security telemetry from any future product
    usage-location statistics.
-   Define retention and access rules before collecting additional
    location data.

### Alerts to consider

-   Sudden increase in 429 responses.
-   Sudden increase in public map/discovery traffic.
-   High request rate from one IP or distributed IP ranges.
-   Login or password-reset spikes.
-   Upload initiation or media-processing spikes.
-   Notification/email bursts.
-   Geospatial query latency or database saturation.
-   High 5xx rate or API latency.
-   Cache/rate-limit-store failures.
-   Unexpected Render resource usage.

Use the existing Sentry setup if present. Do not create one Sentry error
event for every normal 429 response; use metrics, aggregation, or
sampled security events to avoid noise and quota consumption.

### AI implementation prompt

> Add abuse-prevention observability to BeachVolleyballHub using the
> existing logging and monitoring stack where possible.
>
> Inspect Sentry and current logs before introducing new dependencies.
> Add structured throttle events and metrics for 429 responses,
> authentication abuse, map/discovery traffic, uploads, external-service
> usage, cache failures, and resource saturation.
>
> Protect client IP and account identifiers appropriately. Do not log
> tokens, passwords, cookies, full sensitive request bodies, or precise
> user coordinates by default.
>
> Define alert thresholds using baseline traffic rather than arbitrary
> values. Avoid flooding Sentry with expected 429 responses.
>
> Document dashboards, alert routing, retention, and incident
> investigation steps.

------------------------------------------------------------------------

## 16. Phase 11 --- Automated security and regression tests

### Objectives

Prove the protections work across middleware, controllers, jobs,
storage, and frontend behaviour.

### API rate-limit tests

-   Requests below the threshold succeed.
-   Requests above the threshold return HTTP 429.
-   Response body follows the agreed JSON contract.
-   `Retry-After` is meaningful where configured.
-   Counters reset after the expected period.
-   Different authenticated users have independent user-level limits.
-   Account-level limits behave as intended.
-   Anonymous requests use the correctly derived IP.
-   Spoofed forwarding headers cannot bypass throttles.
-   Health checks remain functional.
-   Existing business flows work within the approved limits.

### Geospatial tests

-   Invalid coordinates are rejected.
-   Latitude and longitude bounds are enforced.
-   Radius cannot exceed the configured maximum.
-   Result limits and pagination are enforced.
-   Expensive or malformed queries do not cause unbounded work.
-   Public discovery returns only the intended public/verified records.
-   Repeated requests are throttled or safely cached.

### Authorization tests

-   Cross-account access is rejected.
-   Users cannot modify another organisation's records.
-   Users cannot attach or retrieve another account's media.
-   Role/permission checks are enforced server-side.
-   Location moderation actions require the intended role.

### Upload and job tests

-   Oversized files are rejected.
-   Invalid file content is rejected.
-   Unauthorized upload initiation is rejected.
-   Throttled requests do not enqueue jobs.
-   Duplicate submissions do not create duplicate side effects.
-   Job retries are bounded.
-   Media ownership checks work.

### Notification and external-service tests

-   Throttled requests do not send emails.
-   Throttled requests do not create notifications.
-   Repeated triggers are deduplicated where required.
-   External calls are not made before authorization and limits.
-   Provider failures do not cause unbounded retry loops.

### Shared storage tests

-   Independent cache clients share counters.
-   Multiple application processes share counters.
-   Concurrent requests cannot exceed the intended limit because of race
    conditions.
-   Expired keys are cleaned up.
-   Cache failure follows the documented fallback behaviour.

### Frontend tests

-   429 responses respect `Retry-After`.
-   No immediate infinite retry loop occurs.
-   Non-idempotent writes are not automatically repeated.
-   Form data is preserved.
-   Map requests are debounced and obsolete requests are handled.
-   Normal PWA usage remains functional.

### AI implementation prompt

> Add comprehensive abuse-protection tests to both BeachVolleyballHub
> repositories.
>
> In the API, cover throttling, response contracts, Retry-After, IP
> spoofing, authenticated user/account discriminators, shared storage,
> concurrency, cache failure, geospatial bounds, authorization, uploads,
> jobs, notifications, and absence of side effects for throttled
> requests.
>
> In the frontend, test 429 handling, Retry-After, bounded retry
> behaviour, duplicate submissions, map request debouncing, and
> form-data preservation.
>
> Use the project's existing test frameworks and conventions. Do not
> introduce a new test framework without justification.
>
> Run the relevant suites and report exact commands, results, and any
> remaining gaps. Do not claim Cloudflare behaviour is covered by Rails
> request specs.

------------------------------------------------------------------------

## 17. Phase 12 --- Controlled load testing and staged rollout

### Objectives

Introduce protections safely and measure their effect before tightening
production limits.

### Rollout sequence

1.  Complete the Phase 0 audit.
2.  Approve endpoint limits and failure behaviour.
3.  Deploy shared rate-limit storage.
4.  Deploy conservative Rails throttles.
5.  Observe API latency, 429 rates, and normal user behaviour.
6.  Fix frontend retry and request-frequency issues.
7.  Add Cloudflare edge rules conservatively.
8.  Verify the real API hostname and Render origin behaviour.
9.  Run controlled load tests in staging.
10. Tune limits using measured traffic.
11. Deploy final settings and verify alerts.
12. Document final thresholds and rollback.

### Test scenarios

-   Normal public browsing.
-   Normal authenticated player/coach usage.
-   Organisation administrator planning multiple sessions.
-   Public nearby-organisation searches.
-   Short burst from one IP.
-   Sustained traffic from one IP.
-   Traffic distributed across multiple IPs.
-   Login and password-reset floods.
-   Location proposal spam.
-   Upload initiation and processing floods.
-   Notification/email trigger floods.
-   Expensive geospatial queries.
-   Multiple API processes receiving requests simultaneously.
-   Rate-limit store unavailable or slow.
-   Direct Render-origin access attempt.

Use staging or a specifically approved test environment. Do not run
uncontrolled load or destructive tests against production.

### Acceptance criteria

-   Rate-limit counters are shared across all production API processes
    and instances.
-   Sensitive and expensive endpoints have documented limits.
-   Public discovery/geospatial endpoints have bounded inputs and query
    cost.
-   Authentication abuse is mitigated without easy account-lockout
    attacks.
-   Uploads, jobs, notifications, and external calls have appropriate
    safeguards.
-   Throttled requests return the agreed HTTP 429 contract.
-   Throttled requests do not perform protected side effects.
-   Cloudflare protection is verified on the actual API hostname.
-   Direct-origin exposure is tested and documented.
-   Frontend clients handle 429 responses responsibly.
-   Monitoring and alerts are operational.
-   Automated tests pass.
-   Controlled load tests show the API remains stable under the approved
    scenarios.
-   Rollback and incident-response instructions are documented.

### AI implementation prompt

> Prepare and execute a staged rollout and controlled load-test plan for
> BeachVolleyballHub abuse protection.
>
> Use staging wherever possible. Test normal player/coach workflows,
> public discovery, map searches, authentication abuse, location
> proposal spam, uploads, notification/email triggers, distributed
> traffic, concurrent application processes, and rate-limit-store
> failure.
>
> Measure latency, 429 and 5xx rates, database load, cache performance,
> job queue depth, external-service usage, and Render resource
> consumption.
>
> Confirm that legitimate workflows remain functional and that limits
> are shared across processes.
>
> Do not run uncontrolled tests against production. Provide a rollout
> checklist, rollback plan, results, and final recommended thresholds.

------------------------------------------------------------------------

## 18. Phase 13 --- Documentation and operational runbook

Create or update these documents in the API repository:

``` text
docs/
  security/
    api-abuse-protection.md
    api-rate-limiting.md
    cloudflare-api-protection.md
    geospatial-endpoint-protection.md
    upload-and-media-security.md
    abuse-monitoring.md
    incident-response.md
```

Document:

-   Final rate-limit matrix and rationale.
-   Shared cache architecture and failure behaviour.
-   Cloudflare rules and plan dependencies.
-   Render origin access and mitigation.
-   Public map/geospatial query constraints.
-   Upload limits and media ownership checks.
-   Notification and external-provider safeguards.
-   Frontend 429/retry behaviour.
-   Monitoring and alerting.
-   How to investigate a traffic spike.
-   How to distinguish abuse from a frontend bug or legitimate use.
-   How to adjust a rule safely.
-   How to roll back a problematic deployment.
-   How to rotate origin-verification secrets if used.
-   Security log retention and privacy requirements.

### AI implementation prompt

> Write operational documentation for the completed BeachVolleyballHub
> abuse-protection implementation.
>
> Document the actual code and production configuration, not this
> proposal where implementation differs. Include final throttles, cache
> architecture, Cloudflare configuration, Render origin limitations,
> geospatial safeguards, upload/media protection, authorization
> controls, notification/external-service safeguards, frontend retry
> behaviour, monitoring, testing, deployment, rollback, and incident
> response.
>
> Include practical steps for investigating HTTP 429 responses and
> traffic spikes. Do not include secrets, private user data, or
> sensitive production values.

------------------------------------------------------------------------

## 19. Suggested implementation order

    Order Phase                                             Priority
  ------- ------------------------------------------------- ----------
        1 Audit repositories and production architecture    Critical
        2 Build and approve endpoint risk matrix            Critical
        3 Configure shared rate-limit storage               Critical
        4 Implement Rails/Rack::Attack protection           Critical
        5 Protect public geospatial/discovery endpoints     Critical
        6 Protect uploads, video, and background jobs       High
        7 Protect notifications and external services       High
        8 Review authorization and object enumeration       Critical
        9 Configure Cloudflare and Render origin security   High
       10 Improve frontend 429 and retry behaviour          High
       11 Monitoring and alerting                           High
       12 Automated tests and controlled load testing       Critical
       13 Documentation and incident runbook                Medium

Some phases can run in parallel after the audit. Do not deploy
aggressive limits before normal user workflows and endpoint costs are
understood.

------------------------------------------------------------------------

## 20. Decisions requiring explicit confirmation

1.  Is `api.beachvolleyballhub.com` currently active and proxied through
    Cloudflare?
2.  Can the Render default hostname be used to bypass Cloudflare?
3.  Which Cloudflare protections are available on the current plan?
4.  Is Rack::Attack installed and configured? If so, which rules and
    store are active?
5.  Does the current production cache support atomic shared counters?
6.  How many Render API processes and instances are running?
7.  Which endpoints are public, and which require authentication?
8.  What are the expected normal map/discovery request rates?
9.  What upload sizes and video formats should be supported?
10. Which background jobs and external services can be triggered by API
    requests?
11. What should happen when the rate-limit store is unavailable?
12. What security telemetry can be retained without collecting
    unnecessary precise location data?
13. What are the final approved limits, and who can change them?

------------------------------------------------------------------------

## 21. Definition of done

-   [ ] Both repositories and the production request path have been
    audited.
-   [ ] Existing protections and missing protections are documented with
    source references.
-   [ ] The endpoint risk matrix and final limits are approved.
-   [ ] Rate-limit counters use a verified shared store in production.
-   [ ] Authentication and account-recovery abuse is addressed.
-   [ ] Public organisation, location, and geospatial endpoints are
    protected and bounded.
-   [ ] Organisation, training, tournament, assessment, analysis, and
    comment operations have appropriate controls.
-   [ ] Uploads, video processing, and background jobs have appropriate
    limits.
-   [ ] Notifications, email, weather, and external-service triggers are
    protected.
-   [ ] Cross-account authorization and media ownership tests pass.
-   [ ] HTTP 429 responses follow the agreed API contract.
-   [ ] IP identification is safe against spoofed forwarding headers.
-   [ ] Cloudflare protection is configured and tested on the real API
    hostname.
-   [ ] Direct Render-origin access has been tested and its mitigation
    documented.
-   [ ] Frontend clients handle 429 responses without retry storms.
-   [ ] Monitoring and actionable alerts are active.
-   [ ] Automated tests cover limits, concurrency, cache failure,
    authorization, and side effects.
-   [ ] Controlled load tests have been completed in an appropriate
    environment.
-   [ ] Rollback and incident-response instructions are documented.
-   [ ] Location privacy and security-log retention have been reviewed.
-   [ ] No secrets or sensitive information are committed to either
    repository.

## 22. Important implementation principle

**Do not optimize for returning fewer 429 responses. Optimize for
keeping BeachVolleyballHub available, secure, and fair to legitimate
players, coaches, and organisations.**

A healthy system may return HTTP 429 when a client exceeds a sensible
limit. The objective is to reject abusive traffic early, keep counters
consistent across the deployment, protect expensive volleyball-platform
operations, prevent unauthorized access, and preserve normal app
workflows.
