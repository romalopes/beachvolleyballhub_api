# BeachVolleyballHub Observability Implementation Plan

**Scope:** BeachVolleyballHub Rails API and React front end  
**Status:** Implementation plan; no application code or provider configuration has been changed  
**Repositories:** [`beachvolleyballhub_api`](https://github.com/romalopes/beachvolleyballhub_api) and [`beachvolleyballhub_frontend`](https://github.com/romalopes/beachvolleyballhub_frontend)

## 1. Purpose

Add observability to BeachVolleyballHub in safe, reviewable phases. The initial setup should report API and browser errors, show service health, identify deployments by commit, and alert when public services are unavailable. Add deeper tracing, structured logs, business metrics, Grafana dashboards and alerting only after the baseline is verified.

The application consists of separate API and front-end repositories. Keep them independent. Adapt names, environment variables, health routes, deployment settings and tests to the actual code in each repository. The brand and repository names have changed over time, so verify the configured Render service, production domains, and frontend provider before applying deployment instructions.

## 2. Basis and plan decisions

This plan adapts:

- The attached [Sentry React and Rails guide](sentry_setup_ai_prompts_guide.md).
- GitHub [issue #134: Master Observability Implementation Plan](https://github.com/romalopes/wine_words_api/issues/134), which proposes Sentry, OpenTelemetry, Grafana Cloud, logs, traces, business metrics, RUM, releases and tests across four repositories.
- GitHub [issue #138: implementation checkpoints and safety refinements](https://github.com/romalopes/wine_words_api/issues/138), which requires phase checkpoints, clear alert thresholds, safety review and stopping after each phase.
- The previous Wine Words observability plan, which starts with Sentry, Render, Neon and external uptime checks, then adds OpenTelemetry and Grafana when useful.

The source issues use the older BeachVolleyballProject name and service names. This plan applies the same architecture to **BeachVolleyballHub** and uses `beachvolleyballhub-api` and `beachvolleyballhub-web` as proposed telemetry service names. Update these names only if the deployment configuration shows a different established convention.

### Key design choices

1. **Start with the smallest useful baseline:** Sentry in API and browser, Render and Neon native dashboards, health checks, and external uptime monitors.
2. **Add OpenTelemetry and Grafana later:** begin with backend traces, then add request correlation, logs and metrics as each phase is verified.
3. **Keep Grafana credentials server-side.** The browser must never send telemetry directly to Grafana using a private OTLP authorization token.
4. **Prove trace continuity.** Sentry browser tracing and Grafana OpenTelemetry traces may be separate. Validate propagation between the browser and Rails API before claiming one end-to-end trace.
5. **Use Git SHA as the release ID** across Sentry, OpenTelemetry attributes, logs and deployments wherever supported.
6. **Keep telemetry non-fatal:** exporter errors must not prevent app startup, API responses or training/identity workflows.
7. **Protect player and coach information.** Do not send names, contact details, profile contents, account emails, training notes, assessment answers, or media content by default.
8. **Retain the two repositories as independent apps.** Share naming conventions, not application code.

## 3. Target architecture

| Component | Initial responsibility | Later responsibility |
|---|---|---|
| Sentry Rails project | API exceptions and basic performance | Release/regression alerts and API traces as appropriate |
| Sentry React project | Browser errors and React Error Boundary | Browser tracing/RUM, carefully sampled; source-map symbolication |
| Render dashboard | API logs, CPU, memory, deploys and health | Host-level operational view |
| Neon console (if Neon is the active DB) | Database resource metrics and query history | Continue as the database-native reference; avoid duplication without a need |
| External uptime monitor | Check public front-end and API reachability | Alert on availability from outside the hosting provider |
| Cloudflare Workers observability (if applicable) | Worker runtime logs/errors | Runtime metrics/logs if the front end actually executes Worker code |
| OpenTelemetry Rails SDK | None in the first Sentry-only rollout | Rails, ActiveRecord and outbound HTTP traces; logs/metrics if useful |
| Grafana Cloud | None until the OpenTelemetry phase | Receive OTLP signals, dashboards and alert rules |

A static React deployment on Cloudflare Pages has no application server log stream. Use Sentry in the browser for client-side errors. If the deployed app uses a Cloudflare Worker for runtime code, enable Worker observability for that Worker separately. Verify whether Cloudflare is serving static assets or executing application logic before adding Worker-specific setup.

## 4. Repository and service identity

| App | Repository | Proposed telemetry service | Known deployment context to verify |
|---|---|---|---|
| BeachVolleyballHub API | [`romalopes/beachvolleyballhub_api`](https://github.com/romalopes/beachvolleyballhub_api) | `beachvolleyballhub-api` | Rails API on Render; previous dev endpoint was `https://beachvolleyballproject-dev.onrender.com`; verify current service and custom API domain |
| BeachVolleyballHub front end | [`romalopes/beachvolleyballhub_frontend`](https://github.com/romalopes/beachvolleyballhub_frontend) | `beachvolleyballhub-web` | React/Vite front end; previous deployment target was Cloudflare Workers/Pages; verify active deployment and domain |

Use `development`, `staging` (if it exists) and `production` as environment names. Do not report a development build as production. Confirm the current database provider and whether Cloudflare R2 is used by the API before enabling database or object-storage instrumentation.

## 5. Reusable AI operating rules

Paste this preamble at the top of each phase prompt:

```text
OPERATING RULES FOR THIS PHASE

This is one independent BeachVolleyballHub repository. Do not modify the other
repository. Work only on the requested phase; do not continue to the next phase.

Before editing:
1. Inspect the repository, current branch/status, framework and dependency versions.
2. Find existing Sentry, OpenTelemetry, logging, health-check, request-ID,
   deployment and test configuration. Do not duplicate existing instrumentation.
3. Check current official vendor documentation for the installed versions.
4. Verify actual deployment/provider settings instead of relying on old service
   names or URLs. Never print credential values.
5. Identify compatibility, privacy and deployment risks and state a short plan.

During implementation:
- Preserve current volleyball, training, player/coach identity and organization
  behavior. Do not change business behavior or unrelated code.
- Do not modify the other repository.
- Do not commit secrets or expose server credentials in browser code.
- Do not send player/coach contact details, profile details, training notes,
  assessment answers, private schedules or media content to telemetry by default.
- Avoid high-cardinality labels; keep telemetry/export failures non-fatal.
- Add meaningful tests and update only the documentation for this phase.

At the checkpoint report files changed, dependencies, environment variables,
manual provider steps, commands/tests and exact results, privacy/security
considerations, deployment steps and limitations. Stop and wait before the next
phase.
```

## 6. Phased implementation

### Phase 0 — Audit both repositories and deployments

**Objective:** Establish the actual BeachVolleyballHub architecture before changing code.

**Steps**

1. Audit API and frontend separately; capture branch/status and framework versions.
2. Verify the current Render API service, public URL, environment(s), health check and deploy method.
3. Verify the current frontend build tool, Cloudflare Pages/Workers/Vercel setup, public domain and whether it is static or Worker-backed.
4. Verify database provider (Neon or otherwise), connection adapter, R2/Active Storage usage and external HTTP clients.
5. Identify existing error handling, request IDs, logs, health routes, CORS and tests.
6. Record telemetry-safe identifiers and sensitive data sources, including accounts, contact details, player/coach profiles, invitations, claims, organizations, training schedules and assessments.
7. Recommend a repo-specific change list. Make no edits.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 0: Perform a read-only observability audit of this BeachVolleyballHub
repository.

Inspect actual framework/runtime versions, error handling, logging, request IDs,
health routes, environment variables, CI/CD, hosting configuration and current
monitoring. For the API, identify its database adapter/provider and whether it
uses Cloudflare R2 or Active Storage, without printing credential values. For
the front end, identify the actual deployment provider and whether the deployed
runtime is static assets or a Cloudflare Worker.

Return verified architecture/deployment facts, relevant files, existing
instrumentation, sensitive data that must be scrubbed, proposed changes and
tests for this repository, manual dashboard steps, and unresolved assumptions.
Make no changes.
```

**Checkpoint:** Review the audit and confirm current service names/domains before Phase 1.

---

### Phase 1 — Create the two Sentry projects and configure variables

**Objective:** Separate API and browser error streams.

**Steps**

1. Create a Sentry project using the Rails platform for the API.
2. Create a Sentry project using the React/JavaScript platform for the frontend.
3. Configure the API DSN in Render as `SENTRY_DSN`.
4. Configure the frontend public DSN using the actual bundler prefix (likely `VITE_SENTRY_DSN`).
5. Keep source-map upload tokens and Grafana credentials out of frontend variables and source code.
6. Separate development and production events; add a staging environment only if a staging deployment exists.

**Checkpoint:** Two Sentry projects exist and each deployment has the correct DSN variable without committing the value.

---

### Phase 2 — Add Sentry to the Rails API

**Objective:** Capture API exceptions and useful privacy-safe request context.

**Steps**

1. Confirm `sentry-ruby` and `sentry-rails` compatibility with this API’s Ruby and Rails versions.
2. Configure DSN, environment, Git SHA release and conservative performance sampling.
3. Capture unhandled exceptions while preserving API status codes and response bodies.
4. Exclude expected routing 404s and validation errors from error alerts unless the codebase has a clear reason to keep them.
5. Add request ID, controller/action, and stable internal account/profile IDs only if they help triage. Prefer no names, emails, IP addresses or profile details.
6. Scrub passwords, JWT/bearer tokens, authorization/cookie headers, email verification/invitation tokens, database URLs, payment/email/API credentials, Cloudflare tokens and R2 credentials.
7. Do not include player/coach contact details, organization membership data, training notes, assessment answers or raw request bodies.
8. Add a manual reporting helper only if rescued errors currently disappear and would otherwise be missed. Avoid duplicate capture.
9. Ensure missing Sentry configuration does not break local boot or tests.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 2: Implement Sentry in the BeachVolleyballHub Rails API only.

Use the current official Sentry Rails guidance compatible with this app's
actual Ruby and Rails versions. Load SENTRY_DSN, environment and release from
runtime variables. Capture unhandled exceptions and add only useful context
that already exists in the app, such as request ID and controller/action.
Preserve existing API error responses and do not duplicate existing reporting.

Redact passwords, JWTs, authorization/cookie headers, invitation or account
verification tokens, database URLs, payment/email/API credentials, Cloudflare
and R2 credentials. Do not report expected 404/validation cases as server
failures by default. Do not attach player/coach names, contact details, profile
fields, training notes, assessment answers, or raw request payloads.
Ensure Sentry is optional when its DSN is missing. Add focused tests for
initialization and data filtering. Document Render variables and a safe test
event procedure. Do not deploy or change Render settings.
```

**Checkpoint:** Run API tests; verify a test-only exception arrives in the API Sentry project with the right environment and without sensitive data.

---

### Phase 3 — Add Sentry to the React front end

**Objective:** Capture browser errors and React rendering crashes.

**Steps**

1. Inspect React, Vite, router and TypeScript versions; add the compatible Sentry React SDK.
2. Initialize Sentry once at the app entry point.
3. Add an Error Boundary with a user-friendly fallback that fits the current UI.
4. Add browser tracing only for verified API origins and local development. Do not propagate trace headers to unrelated domains.
5. Keep Session Replay disabled initially. If later enabled, use conservative sampling, mask inputs and block sensitive account, profile, invitation, training and assessment screens.
6. Set/clear a stable user ID only if it is useful and supported by the current authentication flow. Do not attach email, contact details or profile fields by default.
7. If the current build provider supports source-map upload, use a CI-only token and restrict public maps as appropriate.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 3: Implement Sentry in the BeachVolleyballHub React front end only.

Inspect the real React, Vite, router and TypeScript versions. Initialize the
Sentry React SDK once; add an Error Boundary with a clear user-facing fallback;
set the environment and Git-SHA release safely. Capture browser errors without
sending passwords, tokens, cookies, player/coach contact/profile fields,
training schedules/notes, assessment answers or other form content.

If browser tracing is enabled, restrict tracePropagationTargets to the verified
BeachVolleyballHub API and local development origins. Do not enable Session
Replay by default. If a later replay phase is proposed, identify masking and
blocking rules for account, identity, organization, training and assessment
screens before implementing it.

Use the deployment provider confirmed in this repository. If source maps are
uploaded, use a CI secret and never expose the Sentry auth token or Grafana
credentials in the browser bundle. Add focused tests and documentation. Do not
deploy.
```

**Checkpoint:** Lint/typecheck/build/tests pass; a controlled local browser error arrives in the frontend Sentry project.

---

### Phase 4 — Git-based releases and source-map symbolication

**Objective:** Connect deployed errors to the code revision that produced them.

**Steps**

1. Use the deployment commit SHA as immutable release ID: `APP_VERSION` for Rails and a Vite build variable such as `VITE_RELEASE` for the frontend.
2. Set the Sentry release from the same SHA in both apps; do not create a random runtime identifier.
3. Upload source maps during the actual CI/build process if supported. Keep the Sentry auth token in CI secrets; do not expose it in the browser bundle.
4. Reuse the same SHA as OTel `service.version` and `git.commit.sha` in a later phase.
5. Document Render and frontend provider configuration without changing unrelated deployments.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 4: Add Git-SHA-based release identity to this BeachVolleyballHub
repository.

Inspect its actual CI/CD and deployment provider. Use the build/deploy commit
SHA as the immutable Sentry release; configure the correct backend or Vite
variable. Never generate a random release at runtime. If source maps are
supported, upload them during the provider's build using a CI-only Sentry auth
token, and report whether the maps remain publicly accessible. Do not expose
that token or modify unrelated deployment behavior.

Add a test/build-time check for release configuration, document provider
variables, and stop after this phase.
```

**Checkpoint:** Both Sentry projects show a commit SHA release; verify readable frontend stack traces if maps are enabled.

---

### Phase 5 — Health checks, Render/Neon dashboards and external uptime

**Objective:** Detect outages and identify whether an issue is in the app, hosting or database.

**Steps**

1. Inspect existing health routes. Use a lightweight liveness endpoint for frequent Render checks; return no credentials or stack traces.
2. Configure Render’s HTTP health check using the verified route. See [Render health checks](https://render.com/docs/health-checks).
3. Keep frequent liveness separate from optional database readiness checks. If Neon autosuspend is enabled, evaluate whether periodic DB probes affect compute wake-ups before using them as frequent uptime checks.
4. Review Render logs, CPU, memory, deploy history and restarts. Create a memory/restart alert if the available plan/settings support it.
5. Review Neon monitoring and query history if Neon is the active database.
6. Add external uptime monitors for the verified public front-end and API health URLs. Do not rely only on hosting-provider checks.
7. Use Cloudflare Worker logs only if deployed Worker code actually runs the application. Static asset hosting should be monitored via browser Sentry and external uptime checks.
8. Begin with native dashboards; centralize logs later only if retention or multi-service search is a real requirement.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 5: Review safe health-check support for the BeachVolleyballHub API.

Inspect current Rails health routes and Render configuration. Recommend a
lightweight liveness path for frequent Render checks. If a readiness route
queries the database, keep it separate and explain potential effects on Neon
compute wake-ups if autosuspend is enabled. Return exact manual Render steps,
verified API/frontend URLs for uptime monitoring, and how to review Render,
Neon and (if relevant) Cloudflare Worker metrics/logs.

Do not expose secrets or add an unauthenticated diagnostic error endpoint. Do
not modify production settings. If a code change is necessary, propose it
first; implement only after approval, add focused tests and stop.
```

**Checkpoint:** Verify the API health path and external checks return expected results; confirm alerts notify the intended channel.

---

### Phase 6 — OpenTelemetry traces in the Rails API

**Objective:** Collect backend request, database and outbound HTTP spans.

**Steps**

1. Confirm OpenTelemetry Ruby/Rails instrumentation compatibility with the application’s versions.
2. Start with traces: Rails/ActionController, ActiveRecord and the HTTP clients actually used.
3. Set `service.name=beachvolleyballhub-api`, environment, `service.version` and Git commit attributes.
4. Export with OTLP using Render secrets for endpoint and authorization. Never put Grafana credentials in React environment variables.
5. Use conservative success sampling; retain exception capture. Make export failures/timeouts non-fatal and allow telemetry to be disabled.
6. Avoid SQL bind values, request payloads and player/profile/training content in spans.
7. If the app uses R2/Active Storage, instrument only supported storage-client operations and record operation/duration/status, not object contents or credentials.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 6: Add OpenTelemetry traces to the BeachVolleyballHub Rails API.

Check current official OpenTelemetry Ruby/Rails docs and compatibility first.
Instrument incoming Rails requests, ActiveRecord, and only the outbound HTTP
clients/storage clients this repository actually uses. Set service.name to
beachvolleyballhub-api plus environment, service.version and git.commit.sha.
Export OTLP from the API using Render environment secrets only.

Use conservative production sampling; keep initialization and export failures
non-fatal; do not record SQL bind values, credentials, request bodies, player or
coach profile data, contact details, schedules, assessment answers or object
contents. Add tests with a test exporter/mocks; do not require production
Grafana. Document variables and stop after this phase.
```

**Checkpoint:** Test request, database and supported outbound spans are visible via a test exporter; API works with exporter disabled or unavailable.

---

### Phase 7 — Browser-to-API trace propagation and CORS

**Objective:** Continue trace context across the browser/API boundary where supported.

**Steps**

1. Inspect the frontend API client and the installed tracing SDKs; select the actual propagation headers they support.
2. Allow only needed headers such as W3C `traceparent` or Sentry `sentry-trace`/`baggage` in CORS. Do not add headers speculatively.
3. Limit trace targets to verified BeachVolleyballHub API origins and local dev.
4. Confirm Rails accepts incoming context and exports a corresponding backend trace.
5. Treat Sentry-to-Grafana trace correlation as unproven until a test and dashboard show it. Do not export browser telemetry directly to Grafana using private credentials.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 7: Validate browser-to-Rails trace propagation for BeachVolleyballHub.

Inspect the current API client, Rails middleware, CORS policy and SDK support.
Determine which propagation headers are actually emitted. Restrict them to the
verified API origins and allow only those headers in CORS. Do not widen origins
or expose Grafana credentials in the browser.

Add automated tests for preflight and incoming context/trace continuation. Do
not claim a unified Sentry/Grafana trace unless demonstrated. Document the
observed correlation level and stop.
```

**Checkpoint:** Verify browser preflight/header behavior and one backend trace; confirm no headers are sent to third-party domains.

---

### Phase 8 — Structured logs and request/trace correlation

**Objective:** Search production API logs and link them to requests and traces.

**Steps**

1. Preserve human-readable development logs.
2. Check whether Render logs plus Rails request IDs already meet current needs before introducing a JSON logger.
3. If structured JSON is justified, include timestamp, request_id, trace_id/span_id where available, release, environment, HTTP method, route/controller/action, status and duration; add DB runtime only if safely measured.
4. Avoid player/coach names, emails, IPs, organization membership lists, schedules, training notes, assessment answers, request bodies and SQL bind parameters.
5. Keep logs on stdout/stderr so Render can collect them.
6. Do not add a separate log provider until there is a retention or search need.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 8: Improve production log correlation for this BeachVolleyballHub API.

Determine whether existing Rails request IDs and Render logs are adequate.
Prefer the smallest useful change. If JSON logs are justified, retain readable
development output and emit JSON in staging/production with timestamp,
request_id, trace_id/span_id when present, release, environment, method,
route/controller/action, status and duration. Add DB runtime only if safely
available.

Never log authorization/cookie headers, credentials, passwords, JWTs, request
bodies, player/coach names or contact information, organization membership,
training/assessment content, SQL bind values or media contents. Keep output on
stdout/stderr. Add field/redaction tests, document and stop.
```

**Checkpoint:** Inspect a test request in Render and verify IDs/release are present where expected and sensitive fields are absent.

---

### Phase 9 — Grafana Cloud OTLP ingestion

**Objective:** Receive backend OpenTelemetry signals after they work locally/in tests.

**Steps**

1. Create or select a Grafana Cloud stack for BeachVolleyballHub observability.
2. Start with traces; add logs and metrics only after those signals are implemented and tested.
3. Put OTLP endpoint and authorization in Render secret environment variables.
4. Verify service name `beachvolleyballhub-api` and production/development distinction.
5. Send a test span and confirm receipt.
6. Review the selected account’s usage/retention before increasing sampling or enabling high-volume signals.
7. Keep Grafana private credentials out of front-end builds and browser requests.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 9: Configure Grafana Cloud OTLP ingestion for BeachVolleyballHub API
signals that have already been implemented and tested.

Use current official Grafana Cloud instructions. Provide dashboard steps and
variable names, but never request that I place credentials in source code or
this document. Keep endpoint/auth only in Render secrets. Use
beachvolleyballhub-api and the right environment. Verify receipt of a test
trace and explain how to check usage/retention. Do not expose credentials to the
browser and stop after this phase.
```

**Checkpoint:** Confirm a test API trace appears in Grafana and the API remains healthy when export is disabled.

---

### Phase 10 — BeachVolleyballHub product metrics

**Objective:** Add a small number of operational counters with clear event definitions.

Issue #134 lists `assessments_created`, `drills_created`, `drills_published`, `training_sessions` and `player_logins`. Validate these against current models and workflows before implementation. Additional candidate counters may include profile claims or invitations accepted if they answer a real operational question.

| Candidate metric | Definition required before coding | Suggested type |
|---|---|---|
| `assessments_created` | Count a successful persisted assessment; clarify draft vs published | Counter |
| `drills_created` | Count successful drill creation; clarify admin/coach and draft behavior | Counter |
| `drills_published` | Count transition into published state once | Counter |
| `training_sessions_created` | Count successful session creation, not calendar view | Counter |
| `player_logins` | Count successful player login only if the app identifies this role distinctly | Counter |
| `profile_claims_approved` | Count completed/approved claims if this workflow exists and the metric is useful | Counter |
| `profile_invitations_accepted` | Count successful acceptance if the workflow exists and the metric is useful | Counter |

Use only low-cardinality labels such as environment and operation type. Do not label with account/profile/organization IDs, names, emails, skill level, gender, location or other user attributes. Handle retries and duplicate callbacks to avoid overcounting.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 10: Propose minimal BeachVolleyballHub product metrics using the actual
models/workflows. Do not implement until each definition is unambiguous.

Review assessments_created, drills_created, drills_published,
training_sessions_created and player_logins. Check whether profile_claims_approved
or profile_invitations_accepted exist and provide a useful operational signal.
Define the exact domain event, treatment of drafts/retries/moderation, and
whether a counter or histogram is appropriate. Never label metrics with
account/profile/organization IDs, names, email, location, skill level, gender,
training notes, assessment answers or media names.

Return metric definitions and tests first. After review, implement only the
approved metrics, use low-cardinality labels, prevent duplicate counts, and
stop.
```

**Checkpoint:** Approve event definitions before implementation; tests confirm one increment per qualifying event.

---

### Phase 11 — Dashboards and alerts

**Objective:** Provide a few actionable views and production notifications.

**Initial dashboards**

- **API Health:** request rate, error rate, average/p95 latency, slow routes, release.
- **Database:** query duration, top/slow queries, connections and runtime when data is available. Use Neon’s native dashboard for database infrastructure unless centralizing data has a clear benefit.
- **Product activity:** only approved metrics from Phase 10.
- **Frontend/runtime:** Sentry browser issues and, if relevant, Cloudflare Worker errors/duration. Static hosting does not have an application runtime log stream.

**Initial alert candidates**

- Sentry: new critical issue, regression and production error spike.
- Grafana: API unavailable for 2 minutes; latency above 800 ms; error rate above 5%; database timeout/error.
- Hosting: memory restart/instance health alert where available.

The `>800ms`, `>5%`, `2 minutes`, and immediate DB timeout thresholds come from issue #138 and are starting values, not permanent SLOs. Keep alerts production-only, include service/environment and trace/log links where supported, avoid percent thresholds when traffic is too low, document why each threshold exists, and prevent alert loops/duplicate notifications.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 11: Design BeachVolleyballHub dashboards and alerts from telemetry that
actually exists. Do not assume every metric/data source is available.

Propose API Health panels for request rate, error rate, average/p95 latency,
slow routes and release. Add DB panels only where supported. Add product
panels only for approved Phase 10 metrics. Include frontend Sentry issues and
Cloudflare Worker runtime panels only if the deployment actually uses Worker
code.

Propose production-only alert rules using issue #138's starting thresholds:
API latency >800ms, error rate >5%, API down for 2 minutes, and database timeout
or error. Explain low-traffic handling, service/environment labels, links,
email notification, threshold tuning and how duplicate/loop alerts are avoided.
Document each rule's reason. Return the proposed configuration for review
before changing Grafana.
```

**Checkpoint:** Review dashboard and alert conditions using test/staging telemetry before enabling production notifications.

---

### Phase 12 — Automated observability tests

**Objective:** Test instrumentation without production Sentry/Grafana credentials.

**API tests**

- Sentry initialization works with and without a DSN.
- A test exception is captured via mock/test transport.
- Sensitive filtering excludes credentials, profile/contact data and request payloads.
- OTel resource has correct service/environment/release.
- Incoming context creates/continues a trace; SQL/outbound spans appear where expected.
- Logs include request/trace IDs and release without sensitive values.
- Agreed counters increment once and have no high-cardinality labels.

**Frontend tests**

- Sentry initializes once with expected environment and release.
- Error Boundary captures a component error.
- Trace headers go only to the API origin.
- Sensitive forms and user data are not captured.
- Worker runtime behavior is tested separately only if the frontend uses an actual Worker entrypoint.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 12: Add observability tests in this BeachVolleyballHub repository only.

Use mocks, in-memory transports and test exporters. Tests must not require
production Sentry or Grafana credentials. Cover relevant initialization,
DSN/environment/release, exception capture, sensitive-data filtering,
request/trace context, CORS/trace target restrictions, logs and approved
metrics. Separate unit tests, integration tests and deployment smoke tests.
Do not alter volleyball or identity business behavior. Run the relevant tests,
lint/typecheck and build; report exact results and stop.
```

**Checkpoint:** Tests pass without production credentials and do not contact production telemetry endpoints.

---

### Phase 13 — Safe production smoke test

**Objective:** Verify deployed wiring without damaging production data.

1. Confirm deployment and Sentry use the expected Git SHA.
2. Request the public API health URL and front end.
3. Generate a normal API request and confirm Sentry/Grafana signals arrive.
4. Trigger controlled exceptions in staging only. Do not add a public crash endpoint; if a production diagnostic mechanism is ever needed, it must be authenticated, temporary and reviewed.
5. Check browser network requests for CORS and trace propagation.
6. Search Render logs using request ID and Grafana with trace ID where linked.
7. Confirm uptime and Sentry/Grafana notifications reach the intended recipient.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 13: Create docs/observability-smoke-test.md for BeachVolleyballHub.

Document safe steps to verify startup, health checks, Sentry API/browser events,
source maps where supported, OpenTelemetry/Grafana traces, CORS propagation,
Render logs, release identity, metrics and alerts. Use staging for controlled
exceptions. Do not create an unauthenticated production diagnostic endpoint or
include steps that modify production data. Include expected results and
troubleshooting. Do not deploy.
```

**Checkpoint:** Complete the procedure in staging, then use only safe read-only checks in production.

---

### Phase 14 — Documentation and runbook

**Objective:** Make the implementation operable from repository docs.

Create or update the following as appropriate in each repo:

- `docs/observability.md` — architecture, signals, service names and environment variables.
- `docs/observability-development.md` — local setup and event tests.
- `docs/observability-production.md` — Render and frontend provider configuration, without secret values.
- `docs/observability-troubleshooting.md` — missing events, source maps, traces, CORS, alert noise and exporter failures.
- `docs/observability-smoke-test.md` — safe procedure from Phase 13.

Document that browser Sentry DSN/release/environment values are public configuration while Sentry source-map and Grafana tokens, database URLs, Cloudflare tokens and R2 credentials are private. Never write actual credentials into repository docs.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 14: Document only the observability features actually implemented in
this BeachVolleyballHub repository. Do not describe planned features as live.

Cover Sentry, OpenTelemetry, Grafana Cloud, Render/Neon and Cloudflare
monitoring where applicable, logs, metrics, traces, release tracking, local and
production variables, secrets/privacy, testing, deployment, troubleshooting,
alerts and incident investigation. Never include real credentials. Keep the
docs synchronized with code and verified provider configuration. Report files
changed and stop.
```

**Checkpoint:** A developer can set up local telemetry or investigate a production issue from the documentation without access to secret values in the repo.

---

### Phase 15 — Security/privacy audit

**Objective:** Ensure monitoring has not exposed user data or made the app depend on telemetry availability.

Audit for:

- Passwords, JWTs, invitation/claim tokens, authorization/cookie headers, API keys, DB URLs, payment/email credentials, Cloudflare/R2 tokens.
- Player/coach names, contact details, profile attributes, organization membership, training schedules/notes, assessment answers and media content.
- Grafana credentials in frontend bundles or requests.
- Excessive replay capture or public source maps.
- Trace headers sent to third parties or overly broad CORS.
- High-cardinality metric labels, noisy logs, debug logging in production.
- Telemetry exporter failures that could crash/block Rails.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 15: Perform a read-only observability privacy/security audit for this
BeachVolleyballHub repository and its documented deployment configuration.

Check Sentry, OpenTelemetry, Grafana, logs, metrics, replay, source maps, CORS,
trace propagation, frontend bundles, and failure behavior. Specifically check
for secrets and player/coach profile, contact, organization, training,
assessment and media data. Do not print secret values. Return findings with
severity, evidence, affected file/configuration and recommended fix. Do not
modify files until I review findings.
```

After review, use a separate prompt to fix only approved observability findings, run tests, and repeat the audit.

**Checkpoint:** Resolve critical/high credential and privacy issues; telemetry exporters cannot affect app availability.

---

### Phase 16 — Final BeachVolleyballHub checkpoint

**Objective:** Confirm a working and documented observability baseline.

- [ ] API and frontend have separate Sentry projects.
- [ ] API and browser events reach the correct Sentry environment.
- [ ] Events contain useful request/release context and no sensitive player/coach data.
- [ ] Frontend source maps resolve if enabled.
- [ ] Render health checks and external uptime checks work.
- [ ] Neon and Render dashboards are reviewed; Cloudflare Worker monitoring is enabled only if appropriate.
- [ ] Backend OTel traces appear in Grafana if later phases were implemented.
- [ ] Browser/API propagation was tested; no unsupported end-to-end tracing claim remains.
- [ ] Logs and request/trace IDs correlate where supported.
- [ ] Approved product metrics have exact definitions and test coverage.
- [ ] Dashboards and production alerts are reviewed and documented.
- [ ] Release SHA matches across deployment, Sentry, OTel and logs where supported.
- [ ] Tests pass without production credentials.
- [ ] Smoke-test/runbook docs match the implementation.
- [ ] Security/privacy audit is complete.

**AI prompt**

```text
[Paste the reusable AI operating rules above.]

Phase 16: Perform a read-only final observability checkpoint for
BeachVolleyballHub. Compare code, tests, deployment documentation and verified
provider settings against the checklist in this plan. Mark each item complete,
partial, not implemented or blocked. Cite files or dashboard evidence where
available. Identify intentional limitations, unresolved risks and the next
smallest useful step. Do not modify files and do not move on to Wine Words.
```

## 7. Recommended execution order

1. Audit API and frontend separately; verify current Render, Cloudflare and DB setup.
2. Create the two Sentry projects and configure the correct environment variables.
3. Implement and verify API Sentry, then frontend Sentry.
4. Add Git-SHA release identity and source maps where supported.
5. Configure health checks, Render/Neon dashboards and external uptime checks.
6. Decide whether this baseline answers the immediate operational questions.
7. Add Rails OpenTelemetry traces, then test browser-to-API propagation and CORS.
8. Configure Grafana OTLP ingestion for verified backend telemetry.
9. Add structured logs and agreed business metrics if they provide value.
10. Create dashboards/alerts, tests, smoke-test docs and the security review.
11. Stop at each checkpoint and review before starting the next phase.

## 8. References

### Project sources

- [BeachVolleyballHub API repository](https://github.com/romalopes/beachvolleyballhub_api)
- [BeachVolleyballHub front-end repository](https://github.com/romalopes/beachvolleyballhub_frontend)
- [Issue #134 — Master Observability Implementation Plan](https://github.com/romalopes/wine_words_api/issues/134)
- [Issue #138 — implementation checkpoints and safety refinements](https://github.com/romalopes/wine_words_api/issues/138)
- `sentry_setup_ai_prompts_guide.md` — attached Sentry React/Rails guide.
- `wine_words_observability_implementation_plan.md` — companion observability plan for Wine Words.

### Official implementation references

- [Sentry for Rails](https://docs.sentry.io/platforms/ruby/guides/rails/)
- [Sentry Rails tracing](https://docs.sentry.io/platforms/ruby/guides/rails/tracing/)
- [Sentry for React](https://docs.sentry.io/platforms/javascript/guides/react/)
- [Sentry React tracing](https://docs.sentry.io/platforms/javascript/guides/react/tracing/)
- [OpenTelemetry Ruby getting started](https://opentelemetry.io/docs/languages/ruby/getting-started/)
- [OpenTelemetry Ruby instrumentation](https://opentelemetry.io/docs/languages/ruby/instrumentation/)
- [Render health checks](https://render.com/docs/health-checks)
- [Render logs](https://render.com/docs/logging)
- [Render service metrics](https://render.com/docs/service-metrics)
- [Cloudflare Workers observability](https://developers.cloudflare.com/workers/observability/)
- [Neon monitoring](https://neon.tech/docs/introduction/monitoring)
- [Neon query history](https://neon.tech/docs/introduction/monitor-query-history)
- [Better Stack Render logs/metrics integration](https://betterstack.com/docs/logs/render/) (optional if centralizing Render telemetry is later justified)

## 9. Important cautions

- Verify framework/package versions and provider configuration during each phase; do not copy old code snippets blindly.
- Do not assume that Sentry and Grafana automatically show one shared trace. Verify actual context propagation and dashboard linking.
- Keep browser trace targets narrow and CORS origins explicit.
- Never expose Grafana OTLP, Sentry source-map, database, Cloudflare or R2 credentials in browser code or public documentation.
- Do not attach player/coach contact or profile data, training information, assessment answers, or media content to telemetry by default.
- Treat issue #138 thresholds as adjustable starting points and avoid noisy percentage alerts at low traffic.
- Verify and document each phase before proceeding to the next.
