# BeachVolleyballHub — Public Contact Form and Internal Message Inbox

## Implementation plan

**Repositories**
- API: `https://github.com/romalopes/beachvolleyballhub_api`
- Frontend: `https://github.com/romalopes/beachvolleyballhub_frontend`

**Stack:** Rails API + React/Vite frontend  
**Known production domains:** `https://beachvolleyballhub.com` and `https://api.beachvolleyballhub.com`  
**Known deployment context:** Rails API on Render, frontend on Cloudflare, PostgreSQL (Neon has been selected for the production architecture), and a separate background-jobs process is part of the deployment design. Verify current deployment configuration before making changes.

**Feature:** Public contact form, persisted messages, email delivery, internal notifications, and an authenticated inbox for authorized platform staff.

---

## Implementation record

**Status:** Implemented. Each phase below ends with an `Implemented:` note linking
to the document that records what was actually built (files, deviations, tests and
exit criteria), following the convention used by
`docs/IDENTITY_249_Notifications & Bell Implementation Plan/`.

| Phase | Scope | Status | Record |
|---|---|---|---|
| 0 | Repository audit and implementation design | ✅ Complete (audit only) | [PHASE_00_ARCHITECTURE_AUDIT.md](PHASE_00_ARCHITECTURE_AUDIT.md) |
| 1 | `ContactMessage` model, migration, policies, API | ✅ Complete | [PHASE_01_DATA_MODEL_AND_API.md](PHASE_01_DATA_MODEL_AND_API.md) |
| 2 | Email delivery, background job, in-app notifications | ✅ Complete (needs a deployed worker) | [PHASE_02_EMAIL_JOBS_NOTIFICATIONS.md](PHASE_02_EMAIL_JOBS_NOTIFICATIONS.md) |
| 3 | Public React Contact page + Turnstile widget | ✅ Complete | [PHASE_03_PUBLIC_CONTACT_PAGE.md](PHASE_03_PUBLIC_CONTACT_PAGE.md) |
| 4 | Settings → Contact Messages inbox | ✅ Complete | [PHASE_04_INTERNAL_INBOX.md](PHASE_04_INTERNAL_INBOX.md) |
| 5 | Abuse protection, integration, release runbook | ✅ Code + runbook complete; production secrets/worker are operator steps | [PHASE_05_SECURITY_INTEGRATION_RELEASE.md](PHASE_05_SECURITY_INTEGRATION_RELEASE.md) |

### Summary of deviations from this plan

| Plan text | What was built | Why |
|---|---|---|
| Contact "immediately before About" | Top-level public navigation link | There is no About page in this application |
| Inbox shown to Admins/Curators, plan left the guard open | New `PlatformStaffRoute` (curator or admin) + policy | Curators are not admins and must not need the admin console |
| "One notification per recipient" left ambiguous | One email addressed to all configured recipients | Atomic retry; avoids duplicate partial sends |
| `CONTACT_NOTIFICATION_EMAILS` recipients | Implemented exactly, `MAIL_REPLY_TO` untouched | Header vs recipient list are different concepts |
| Worker verification | `CONTACT_NOTIFICATION_EMAILS` added to the existing `bvb-api-worker` (and `bvb-api`) in `beachvolleyballhub_api/render.yaml` | The worker already existed; it only needed the new variable |
| Optional metadata endpoint for categories | Implemented as `GET /api/v1/contact_messages/options` | Keeps one backend source of truth for the allowlist |

### Verification summary

| Command | Result |
|---|---|
| `bin/rails test test/{models,policies,lib,services,mailers,jobs}/*contact* …` (phase 1/2/5 suites) | 94 runs, 349 assertions, 0 failures |
| `bin/rails test` (full API suite) | 1928 runs, 0 errors, 2 pre-existing failures (unrelated: mail transport + weather share) |
| `npx vitest run` on the new pages + sidebar | 54 tests passing |
| `npm run build` / `tsc -b` | ✅ |
| `bin/rubocop` on all new/changed API files | 17 files, no offenses |
| `npm run lint` | No errors in files added or changed by this feature |

---

## 1. Objective

Add a public **Contact** entry to the BeachVolleyballHub navigation, positioned immediately before **About** if About exists in the current navigation. If the current menu has no About item, place Contact in the public navigation according to the established product information architecture and document the placement decision.

Visitors can submit a general enquiry without registering or signing in. Persist each submission in the database, email configured contact recipients, and create in-app notifications for the appropriate platform staff.

Add **Settings → Contact Messages** for authorized staff to search, filter, read, mark unread, and archive incoming messages.

This is a lightweight inbox, not a full ticketing or CRM system. Replies remain outside the initial scope and can be sent from the recipient's normal email application.

## 2. Product decisions

| Area | Decision |
|---|---|
| Public access | No account or login required |
| Navigation | Contact before About if About exists |
| Contact categories | BeachVolleyballHub-specific dropdown |
| Persistence | New `contact_messages` table |
| Email recipients | Dedicated `CONTACT_NOTIFICATION_EMAILS` configuration |
| Reply address | Preserve existing `MAIL_REPLY_TO` meaning; use visitor email as Reply-To where supported |
| In-app notifications | Active platform Admins and Curators by default; verify exact role semantics in Phase 0 |
| Coaches | Do not notify all Coaches by default; they are not the platform-wide support team |
| Inbox access | Admins and Curators, subject to existing authorization semantics |
| Message states | `unread`, `read`, `archived` |
| Delete | No delete action in the initial UI |
| Spam controls | Cloudflare Turnstile, rate limiting, honeypot, validation |
| Reply workflow | Not included initially |
| Attachments | Not included initially |

### Role and authorization decision

BeachVolleyballHub has domain roles and account/membership concepts. Do not assume that a role named Admin or Curator is global. In Phase 0, inspect whether these roles are platform-wide, account-scoped, organization-scoped, or represented through separate permission records.

Recommended product behavior:
- Platform Admins and Curators manage general public contact enquiries.
- Coaches do not automatically receive every platform contact message.
- If the existing system has a distinct support/admin permission, use that permission rather than creating another role.
- Do not grant access merely because a user belongs to an organization.
- Ensure a message containing a player's, coach's or organization's personal information is visible only to authorized platform staff.

If the current role model cannot safely distinguish platform staff from organization-level roles, stop and document the required permission decision before implementing the inbox.

### Important email configuration distinction

Do not silently reinterpret `MAIL_REPLY_TO` as a comma-separated recipient list if the application already uses it as a reply-to header. Email `Reply-To` and delivery recipients are different concepts.

Preferred configuration:

```env
CONTACT_NOTIFICATION_EMAILS=support@beachvolleyballhub.com,admin@beachvolleyballhub.com
MAIL_REPLY_TO=support@beachvolleyballhub.com
```

Inspect actual use of `MAIL_REPLY_TO` before changing anything. Preserve existing behavior and document a safe migration. Parse recipients, trim whitespace, reject invalid addresses, remove duplicates, and fail safely when no recipient is configured. Never expose recipient addresses in the public API.

Use the existing mail delivery provider, mailer conventions and background-job process. Do not introduce another email provider solely for this feature. Verify that the production worker is actually deployed and processing the relevant queue.

## 3. Repository discovery and compatibility rules

Before implementation, inspect both repositories and document actual conventions. Do not assume names or invent architecture.

### API discovery
- Rails/Ruby versions, database adapter, migration conventions and schema.
- User, Account, Person, PlayerProfile, CoachProfile and membership relationships where relevant.
- Role and permission implementation, especially platform Admin/Curator versus organization-level roles.
- Existing notification model, notification creation service, recipient targeting, unread counts and frontend notification API.
- Existing mailers, delivery jobs, sender configuration, `MAIL_REPLY_TO` and provider integration.
- Existing Rack::Attack configuration and whether middleware is actually enabled in each environment.
- Existing Cloudflare Turnstile verification, WAF and rate-limit integration.
- API namespaces, serializers, pagination, error response format and authorization policy approach.
- Background worker process, queue configuration, retry policy and monitoring.
- Existing test framework and factories/fixtures.

### Frontend discovery
- React/Vite versions, router and layout conventions.
- Public navigation and About route, if present.
- Settings navigation and role/permission guards.
- Existing form, validation, API client, toast and loading patterns.
- Existing notification badge/count integration.
- Existing table/list, pagination, filters and responsive design components.
- Existing accessibility and test conventions.
- Production frontend hosting and build-time environment configuration.

### Deployment discovery
- Confirm the current Cloudflare Pages/Worker frontend deployment and custom domain.
- Confirm current Render API service, environment, health checks and background worker.
- Confirm actual production API base URL and CORS allowlist.
- Confirm Neon database connection and migration/deployment process.
- Confirm Turnstile widget hostnames and secret storage.
- Confirm Sentry and existing operational logging/monitoring.

### Non-negotiable compatibility
- Reuse existing roles and permissions; do not create duplicate role systems.
- Reuse existing notification infrastructure.
- Reuse existing mailer, delivery jobs and background worker.
- Keep public submission endpoints separate from protected inbox endpoints.
- Follow current API response and error conventions.
- Do not alter PlayerProfile, CoachProfile, organization membership, training, tournament, assessment, analysis or weather behavior.
- Do not expose player/coach profile or training information through this feature.
- Do not add dependencies without explaining why they are necessary.
- Preserve production configuration and backward compatibility.
- Keep secrets out of source control and frontend bundles.

---

# 4. Functional requirements

## 4.1 Public Contact page

Suggested route: `/contact`

The page must be accessible to anonymous visitors and authenticated users.

### Form fields

| Field | Required | Suggested constraints |
|---|---:|---|
| Name | Yes | Trimmed; sensible maximum, e.g. 120 characters |
| Email | Yes | Valid email format; maximum 254 characters |
| Contact type | Yes | One of the server-supported values |
| Subject | Yes | Trimmed; maximum 180 characters |
| Message | Yes | Non-empty; maximum 10,000 characters |
| Turnstile token | Yes when enabled | Verified server-side |
| Honeypot | No visible input | Must remain empty |

Suggested BeachVolleyballHub contact types:

| API value | Display label |
|---|---|
| `general` | General enquiry |
| `account_access` | Account or login support |
| `coaching` | Coaching enquiry |
| `organisation` | Organisation or club enquiry |
| `training_tournament` | Training or tournament enquiry |
| `location` | Court or location information |
| `technical_support` | Technical support |
| `partnership` | Business or partnership |
| `feedback` | Feedback or suggestion |
| `other` | Other |

Do not accept arbitrary category strings from the client. Keep accepted values in one backend source of truth and expose options through a public metadata endpoint if that matches existing API patterns.

### User experience
- Explain briefly what the form is for.
- Identify required fields.
- Validate on the client for usability and always validate again on the server.
- Prevent duplicate submissions while a request is in progress.
- Show success only after the API confirms persistence.
- On failure, retain entered values where safe and show an actionable error.
- Do not expose internal recipient addresses, stack traces or implementation details.
- Ensure keyboard accessibility, labels, focus states and mobile layout.
- Provide a privacy note explaining that submitted information is used to respond to the enquiry.
- Do not require registration.
- Tell users not to include passwords, payment details, medical details, private information about minors, or other sensitive information in the message.
- Do not request player profiles, training schedules, assessments or private organization details through this general form. Direct users to the appropriate authenticated workflow where applicable.

## 4.2 Message persistence

Create a `ContactMessage` model and `contact_messages` table.

Suggested fields:

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | Primary key |
| `name` | string | Required |
| `email` | string | Required |
| `contact_type` | string | Required; validated allowlist |
| `subject` | string | Required |
| `message` | text | Required |
| `status` | string | Required; default `unread` |
| `read_at` | datetime | Nullable |
| `archived_at` | datetime | Nullable |
| `created_at` | datetime | Rails timestamp |
| `updated_at` | datetime | Rails timestamp |

Do not add a `user_id` requirement: anonymous visitors must be able to submit. If the application has an established optional submitter association, it may be considered, but do not link a message to an authenticated account merely because a browser happens to have a session. The form remains a public communication channel.

Consider adding `email_delivery_status` only if the existing delivery architecture needs durable tracking. Do not store Turnstile tokens, honeypot values or unnecessary request metadata in the message record.

### Model behavior
- Normalize name, email, subject and contact type safely.
- Trim surrounding whitespace.
- Validate required fields and maximum lengths.
- Validate email format.
- Validate contact type against the allowlist.
- Validate status against supported states.
- Keep message content as plain text; escape it when rendered in HTML.
- Set `read_at` when transitioning to read.
- Clear `read_at` when transitioning back to unread.
- Set `archived_at` when archived.
- Define consistent behavior when an archived message is marked read or unread. Recommended: changing to read/unread unarchives it.
- Do not hard-delete messages through the initial UI.

### Indexes
Add indexes based on actual query patterns:
- `status`
- `contact_type`
- `created_at`
- Optional composite index for common status/date sorting.

Avoid redundant indexes. Confirm migration behavior against the production database engine and existing conventions.

## 4.3 Public API

Follow the existing API namespace/version and response conventions. Suggested shape (adapt to the repository):

- `GET /api/v1/contact_messages/options` — public supported contact categories, if needed.
- `POST /api/v1/contact_messages` — public submission.

The public create endpoint must:
1. Validate request shape and permitted fields.
2. Verify Turnstile server-side.
3. Apply rate limits.
4. Validate the honeypot.
5. Validate all message fields.
6. Persist the message.
7. Enqueue email delivery and staff notifications after commit.
8. Return a minimal success response that does not reveal internal data.

Do not allow public clients to set `status`, `read_at`, `archived_at`, recipient lists, notification recipients or internal fields.

### Transaction and delivery reliability
A message must not be lost because email delivery or notification delivery fails.

Recommended:
- Persist the message first.
- Enqueue delivery work after commit using the existing Active Job pattern.
- Make delivery jobs retryable and safe to run more than once.
- Track failures through existing job/error monitoring.
- Avoid sending mail inside a database transaction.
- Ensure job enqueue failure is observable; decide whether API returns success with operational alert or a retryable error based on established application reliability patterns.
- Consider a transactional outbox only if current architecture needs stronger guarantees; do not introduce it unnecessarily.

## 4.4 Email delivery

Create a mailer, for example `ContactMessageMailer`, using existing conventions.

Email contents:
- Sender name and email.
- Contact category (human-readable label).
- Subject.
- Full message.
- Submission date/time and timezone.
- Link to the authenticated Contact Messages detail page.

Email behavior:
- Send to every configured address in `CONTACT_NOTIFICATION_EMAILS`.
- Set a safe, configured sender address.
- Set `Reply-To` to the validated sender email if supported by current mail configuration.
- Do not use visitor email as SMTP `From`; this can fail SPF/DMARC and invite spoofing.
- Escape all user-controlled content in HTML email.
- Provide a plain-text alternative.
- Never allow CR/LF header injection.
- Do not include secrets or Turnstile tokens.
- Handle missing/invalid recipient configuration explicitly and log a safe operational error.

Use a background job for delivery. If one recipient fails, decide whether delivery retries the entire recipient set or tracks recipients independently. Avoid duplicate messages on retries where possible.

## 4.5 In-app notifications

Notify all active platform Admins and Curators, using the exact role semantics established in Phase 0.

Requirements:
- Reuse existing notification model and creation service.
- Do not notify every Coach or every organization member by default.
- If existing product permissions identify a platform support/admin permission, prefer that permission.
- Exclude inactive, suspended and deleted users.
- Avoid duplicate notifications if a job retries.
- Do not notify broad organization memberships unless the role model explicitly requires it.

Notification content:
- Title: `New contact message`
- Body: sender name, category and subject (concise).
- Link/target: Contact Message detail route.
- Type/key: use existing notification conventions.

Ensure the existing notification badge/unread count updates through current frontend behavior. Do not leak message content to users who cannot open the inbox.

---

# 5. Internal inbox and authorization

## 5.1 Navigation

Add **Settings → Contact Messages**.

Show the item only to authorized platform Admins and Curators (or the existing equivalent permission identified in Phase 0). Backend authorization is mandatory; hiding the menu is not security.

Display an unread count if it fits the existing navigation pattern. Count only messages that are not archived and are unread, unless existing product conventions indicate otherwise.

## 5.2 Protected API

Suggested endpoints; adapt to current routes and conventions:

- `GET /api/v1/admin/contact_messages`
- `GET /api/v1/admin/contact_messages/:id`
- `PATCH /api/v1/admin/contact_messages/:id` — permitted status transitions only.

Potential query parameters:
- `status`
- `contact_type`
- `search` (name, email, subject)
- `page`
- `per_page`
- `sort` (restrict to allowlisted fields/directions)

Do not permit arbitrary SQL sort expressions or unbounded page sizes.

### Authorization matrix

| Action | Anonymous | Player/Reader | Coach | Curator | Platform Admin |
|---|---:|---:|---:|---:|---:|
| Submit public contact form | Yes | Yes | Yes | Yes | Yes |
| List messages | No | No | No by default | Yes* | Yes |
| View message | No | No | No by default | Yes* | Yes |
| Mark read/unread | No | No | No by default | Yes* | Yes |
| Archive | No | No | No by default | Yes* | Yes |

`*` Curator access must be confirmed against actual platform-level permission semantics. Organization-level Curator access must not automatically imply access to all platform contact messages.

The exact role names may differ in code. Map the matrix to existing permissions; do not add a new role merely to match the table.

## 5.3 Inbox list page

Features:
- Paginated newest-first list.
- Sender name and email.
- Contact type.
- Subject.
- Submission date/time in the application's chosen timezone convention.
- Read/unread indicator.
- Archived indicator or separate archived filter.
- Search by sender, email or subject.
- Filter by contact type and status.
- Loading, empty, error and retry states.
- Responsive layout for desktop and mobile.
- Accessible table/list semantics.

Suggested status views:
- All
- Unread
- Read
- Archived

Archived messages should not inflate the unread badge.

## 5.4 Message detail page or panel

Display:
- Sender name.
- Sender email (with a safe `mailto:` action if consistent with UI patterns).
- Contact type.
- Subject.
- Full message as escaped plain text.
- Received date/time.
- Current status.

Actions:
- Mark as read.
- Mark as unread.
- Archive.
- Return to inbox.

Mark as read when opened only if consistent with the application's UX; otherwise provide an explicit action. Make status changes idempotent.

No inline reply, attachments, forwarding or permanent deletion in this release.

---

# 6. Security, privacy and abuse prevention

Public forms are an abuse target. Implement layered controls.

## 6.1 Cloudflare Turnstile
- Add frontend site key configuration, e.g. `VITE_TURNSTILE_SITE_KEY`.
- Add backend secret configuration, e.g. `TURNSTILE_SECRET_KEY`.
- Verify tokens on the server using Cloudflare Siteverify.
- Validate success, expected hostname and action where configured.
- Treat missing, invalid, expired or replayed tokens as failed verification.
- Never trust a client-side success callback.
- Keep secret keys out of Vite variables and frontend bundles.
- Support development/test configuration without weakening production.
- Use a test verifier/service double in automated tests.
- Document Cloudflare widget hostname and production domain configuration.

If Turnstile is unavailable, fail closed in production unless an explicitly approved operational fallback exists. Do not silently disable verification.

## 6.2 Rate limiting
Inspect the existing Rack::Attack configuration and confirm that middleware is enabled in the production application. Do not assume that defining throttles means they are active.

Suggested initial limits (tune using real traffic):
- Per IP: 5 submissions per 10 minutes.
- Per IP: 20 submissions per day.
- Add a separate short burst limit if needed.

Consider shared NATs and legitimate club/venue users. Return HTTP 429 with a generic retry message. Do not reveal internal rate-limit keys or infrastructure details.

If the API runs behind Render/Cloudflare or another proxy, verify trusted proxy configuration before relying on client IP headers. Never blindly trust arbitrary `X-Forwarded-For` values.

Cloudflare WAF/rate limiting and Bot Fight Mode can complement, but do not replace, Rails-side controls.

## 6.3 Honeypot and input abuse
- Add a visually hidden, accessible-safe honeypot field.
- Do not use CSS that makes the field confusing for screen readers.
- Reject or quietly discard submissions with the honeypot populated according to the application's abuse policy.
- Enforce request body and field length limits.
- Reject unsupported content types and malformed payloads.
- Avoid accepting HTML as message content.
- Consider duplicate-message throttling without storing excessive fingerprints.

## 6.4 XSS, injection and email safety
- Render message content as escaped plain text, never trusted HTML.
- Escape content in HTML email templates.
- Do not interpolate user input into SQL or shell commands.
- Validate and normalize email addresses.
- Prevent CR/LF header injection.
- Do not accept recipient addresses from the public request.
- Do not expose stack traces or internal IDs unnecessarily.

## 6.5 Beach volleyball domain privacy
This feature must not weaken existing privacy controls for:
- Player and Coach profiles.
- Profile claims and invitations.
- Organization membership and account information.
- Training sessions and schedules.
- Tournaments.
- Assessments and analysis media.
- Location and venue information where access is restricted.

The Contact inbox is a separate platform-level communication channel. Do not automatically associate messages with a PlayerProfile, CoachProfile, Account, Organization, TrainingSession or Tournament based on untrusted form input.

The form should discourage visitors from submitting private details about minors, health information, credentials, private training arrangements or other sensitive data. If a user needs help with a specific account or private record, staff should direct them to an authenticated support workflow rather than asking them to put private details into the public form.

## 6.6 Privacy and retention
- Collect only fields needed to respond.
- Add a concise privacy notice.
- Do not log full message bodies or email addresses unnecessarily.
- Restrict message access to authorized platform roles.
- Decide a retention policy with the product owner; do not implement automatic deletion in this release.
- Ensure messages are not included in public search, sitemap, analytics payloads or public API responses.
- Follow the project's privacy policy and applicable Australian privacy obligations as relevant.

## 6.7 Observability
Use existing Sentry/logging/monitoring integrations. Record operational events without logging message content:
- Submission accepted/rejected.
- Turnstile verification failure.
- Rate-limit event.
- Email job success/failure.
- Notification job success/failure.
- Unauthorized inbox access.
- Unexpected processing errors.

---

# 7. Implementation phases and AI coding prompts

Each prompt is intended for Codex/Cline with the relevant repository open. Complete and review one phase before proceeding.

## Phase 0 — Repository audit and implementation design

**Repositories:** API and frontend  
**Goal:** Confirm architecture and produce an implementation map without changing code.

### Tasks
1. Inspect both repositories and current branch/status.
2. Identify public navigation and About route, if present.
3. Identify Settings navigation and role guards.
4. Inspect Admin/Curator/Coach role semantics and distinguish platform roles from organization roles.
5. Inspect notification models/services/jobs and frontend unread badge.
6. Inspect mailers, delivery jobs, `MAIL_REPLY_TO` and all uses of it.
7. Inspect Rack::Attack and verify middleware activation.
8. Inspect Turnstile, Cloudflare WAF and existing rate limits.
9. Inspect API routes, serializers, pagination and errors.
10. Verify Render API and background worker configuration, Cloudflare frontend deployment, Neon database and production domains.
11. Identify test commands and relevant tests.
12. Propose exact files to create/change and compatibility concerns.

### Acceptance criteria
- No code changes.
- Clear architecture map.
- Explicit confirmation of platform Admin/Curator semantics.
- Explicit confirmation of `MAIL_REPLY_TO` semantics.
- Confirm whether the background worker is deployed and processing jobs.
- Confirm Rack::Attack middleware is active.
- No duplicate notification, mail, role or authorization systems proposed.
- Risks and unresolved decisions listed.

### AI prompt

```text
You are working on the BeachVolleyballHub application.

Repositories:
- API: https://github.com/romalopes/beachvolleyballhub_api
- Frontend: https://github.com/romalopes/beachvolleyballhub_frontend

We need to plan a public Contact form and an internal Contact Messages inbox.

Do an architecture audit only. Do not modify files.

Inspect:
1. Rails/Ruby versions, database, models, API routes and response conventions.
2. User, Account, Person, PlayerProfile, CoachProfile, organization and membership relationships where relevant.
3. Exact role and permission semantics: platform Admin, Curator and Coach versus organization-level roles.
4. Existing notifications, notification jobs/services, unread counts and frontend integration.
5. Existing mailers, delivery jobs, provider configuration, sender and every use of MAIL_REPLY_TO.
6. Existing Rack::Attack configuration and verify middleware activation in production.
7. Existing Cloudflare Turnstile verification and other anti-abuse controls.
8. React router, public navigation, About page if present, Settings navigation and permission guards.
9. Existing forms, validation, API client, pagination, list/table and toast components.
10. Render API and worker configuration, Cloudflare frontend deployment, Neon database configuration, production domains, CORS and Sentry.

Return:
- Concise architecture summary with exact file paths.
- Existing services/components that must be reused.
- Whether Admin/Curator roles are platform-wide or scoped.
- Whether the background worker is actually deployed and processing jobs.
- Whether Rack::Attack is actually active.
- Actual MAIL_REPLY_TO semantics.
- Recommended API endpoint contract.
- Exact implementation files and phase sequence.
- Security/privacy risks and unresolved decisions.

Do not modify files. Do not invent conventions. Do not create a new role, notification, mail delivery or authorization system.
```

> **Implemented (audit only):** ✅ See [PHASE_00_ARCHITECTURE_AUDIT.md](PHASE_00_ARCHITECTURE_AUDIT.md) for the verified architecture (Rails 8.1.3 / Ruby 3.4.2 / Solid Queue / Pundit), the proof that `admin` and `curator` are **platform-wide** roles while organisation roles live on `OrganisationMembership`, the actual `MAIL_REPLY_TO` semantics (a Reply-To header — preserved), the Rack::Attack state, the missing Turnstile integration and the missing Render worker.

## Phase 1 — Rails model, migration and API

**Repository:** `beachvolleyballhub_api`

### Tasks
1. Create migration and `ContactMessage` model.
2. Add status and contact-type validation using repository conventions.
3. Add indexes.
4. Add public submission endpoint.
5. Add protected inbox index/show/update endpoints.
6. Add policy/authorization checks for platform Admins/Curators.
7. Add filtering, search, sorting and pagination with safe allowlists.
8. Add status transition behavior and timestamps.
9. Add model/request/policy tests.
10. Document API contract.

### Acceptance criteria
- Anonymous visitors can submit valid messages.
- Invalid categories and fields are rejected server-side.
- Public users cannot list or read messages.
- Player/Reader/Coach and organization-only Curator users cannot access the platform inbox unless explicitly authorized by existing platform permissions.
- Authorized platform Admins/Curators can list and view messages.
- Status updates are authorized and idempotent.
- Filtering and pagination are bounded and safe.
- Public response exposes no internal recipients or management fields.
- Tests cover role and account-scope boundaries.

### AI prompt

```text
Implement Phase 1 of the BeachVolleyballHub Contact feature in the Rails API repository.

Use the architecture findings from Phase 0 and follow actual repository conventions.

Implement:
- ContactMessage migration and model.
- Fields: name, email, contact_type, subject, message, status, read_at, archived_at, timestamps.
- Contact type allowlist:
  general, account_access, coaching, organisation, training_tournament,
  location, technical_support, partnership, feedback, other.
- Status values: unread, read, archived.
- Validation, normalization and indexes.
- Public create endpoint for anonymous submissions.
- Protected inbox endpoints for list, show and permitted status updates.
- Authorization using existing platform-level Admin/Curator permissions.
- Search by name/email/subject, filters by status/type, bounded pagination and safe sorting.
- Existing API error and serialization conventions.

Do not implement email or notifications yet; those are Phase 2.

Important domain/privacy constraints:
- Do not associate a public message automatically with a PlayerProfile, CoachProfile, Account, Organization, TrainingSession or Tournament.
- Do not expose player/coach profiles, training information, assessments, analysis media or private location data.
- Organization-level roles must not automatically receive platform inbox access.
- Do not create new roles if existing permissions can represent this access.

Security:
- Never permit public clients to set status, timestamps, recipient addresses or internal fields.
- Do not expose inbox endpoints to anonymous users or unauthorized roles.
- Store message content as plain text and render escaped.
- Avoid SQL injection and unbounded queries.

Tests:
- Model validations and allowed values.
- Anonymous successful submission.
- Invalid and malformed requests.
- Authorization matrix including organization-scoped role cases.
- Search, filters, pagination and status transitions.
- Public response does not leak internal data.

Run relevant tests and lint. Report files changed, migration, test results and remaining issues. Do not modify unrelated features.
```

> **Implemented:** ✅ See [PHASE_01_DATA_MODEL_AND_API.md](PHASE_01_DATA_MODEL_AND_API.md). Files: `db/migrate/20261117000001_create_contact_messages.rb`, `app/models/contact_message.rb`, `app/policies/contact_message_policy.rb`, `app/controllers/api/v1/contact_messages_controller.rb`, `app/controllers/api/v1/admin/contact_messages_controller.rb`, `config/routes.rb`, `test/fixtures/contact_messages.yml` and four test files.
>
> Deviations from the prompt, all documented in the phase file: an extra `GET /api/v1/contact_messages/options` publishes the category allowlist; the list endpoint returns per-status `counts` for the inbox tabs; `emailed_at`/`notified_at` columns exist for Phase 2 idempotency. Denials follow the app-wide contract — read-by-id for an unauthorised caller is **404**, not 403.

## Phase 2 — Email, background jobs and notifications

**Repository:** `beachvolleyballhub_api`

### Tasks
1. Implement recipient configuration parsing.
2. Preserve and document existing `MAIL_REPLY_TO` semantics.
3. Add `CONTACT_NOTIFICATION_EMAILS` unless audit proves an existing variable already represents recipients.
4. Implement `ContactMessageMailer`.
5. Implement background delivery job(s).
6. Notify all active platform Admins/Curators using the existing notification service.
7. Make jobs retry-safe and avoid duplicate notifications.
8. Verify the Render worker/production job process handles the queue.
9. Add tests for recipient parsing, mail content, job behavior and notification targeting.
10. Add environment-variable documentation.

### Acceptance criteria
- Each configured recipient receives an email.
- Sender email is Reply-To, not From.
- User input is escaped in HTML and available in plain text.
- Mail failure does not delete the persisted message.
- All eligible active platform Admins/Curators receive one notification.
- Organization-level Curators, Coaches and inactive users are excluded unless existing platform permissions explicitly authorize them.
- Retried jobs do not create duplicate notifications.
- No recipient address or secret is exposed publicly.
- Production worker processes the new jobs.

### AI prompt

```text
Implement Phase 2 of the BeachVolleyballHub Contact feature in the Rails API repository.

Reuse existing mailer, background-job, notification and delivery infrastructure discovered in Phase 0.

Email:
- Send to every configured contact recipient.
- Prefer CONTACT_NOTIFICATION_EMAILS as a comma-separated environment variable.
- Inspect and preserve actual MAIL_REPLY_TO behavior. Do not repurpose it without a compatibility plan.
- Use the configured application sender address as From.
- Set Reply-To to the validated visitor email where supported.
- Include sender, category, subject, message, submission time and authenticated inbox link.
- Provide HTML and plain-text bodies.
- Escape user-controlled values and prevent header injection.

Notifications:
- Notify every active platform Admin and Curator according to existing permission semantics.
- Do not notify all Coaches or organization members by default.
- Reuse existing notification model/service/type conventions.
- Link to the Contact Message detail route.
- Ensure retry-safe behavior and avoid duplicate notifications.

Reliability:
- Persist the ContactMessage before asynchronous delivery.
- Enqueue after commit.
- Use existing retry/error-monitoring patterns.
- A delivery failure must not lose the message.
- Verify the deployed Render worker processes the relevant queue.
- Handle missing/invalid recipient configuration explicitly.

Tests:
- Recipient parsing, trimming, deduplication and invalid addresses.
- Email headers, recipients, content and escaping.
- Correct platform Admin/Curator targeting.
- Organization-scoped Curators and Coaches excluded where appropriate.
- Retry/idempotency behavior.
- Message remains persisted after delivery failure.

Update environment documentation and run relevant tests. Do not introduce a new provider or notification framework.
```

> **Implemented:** ✅ See [PHASE_02_EMAIL_JOBS_NOTIFICATIONS.md](PHASE_02_EMAIL_JOBS_NOTIFICATIONS.md). Files: `lib/contact_recipients.rb`, `app/mailers/contact_message_mailer.rb` (+ HTML/text views), `app/jobs/contact_message_delivery_job.rb`, `app/services/notifications/workflow_events.rb` (`contact_message_received`), `render.yaml`, `.env.example` and three test files.
>
> Notable decisions: one mail to all configured recipients (atomic, retry-safe) instead of one send per address; `MAIL_REPLY_TO` untouched; `CONTACT_NOTIFICATION_EMAILS` was added to both `bvb-api` and the existing `bvb-api-worker` in `beachvolleyballhub_api/render.yaml` (the worker already existed — it only needed the new recipient variable and the shared mail settings).

## Phase 3 — Public React Contact page

**Repository:** `beachvolleyballhub_frontend`

### Tasks
1. Add Contact navigation entry in the correct public menu position.
2. Add `/contact` route.
3. Build responsive form.
4. Implement contact category options matching API.
5. Integrate API client and server validation errors.
6. Integrate Cloudflare Turnstile.
7. Add honeypot field.
8. Add loading, success, error and retry states.
9. Add accessible labels, keyboard behavior and privacy note.
10. Add component/integration tests.

### Acceptance criteria
- Contact appears before About if About exists; otherwise placement follows the audited navigation design.
- Page is accessible without login.
- Form works on mobile and desktop.
- Client validation improves usability but server remains authoritative.
- Turnstile token is sent to API and never treated as verified by the client.
- Duplicate submission is prevented while pending.
- Success is shown only after confirmed API success.
- Errors are understandable and do not expose internal details.
- No secret key is included in frontend build.
- Privacy note discourages sharing sensitive player/coach/minor information.

### AI prompt

```text
Implement Phase 3 of the BeachVolleyballHub Contact feature in the React/Vite frontend repository.

Inspect and reuse existing routing, navigation, form, validation, API, toast and styling conventions.

Implement:
1. Add Contact to the public navigation, immediately before About if About exists.
2. Add a public /contact route.
3. Create a responsive Contact form with:
   - Name
   - Email
   - Contact type
   - Subject
   - Message
   - Cloudflare Turnstile
   - Honeypot
4. Use API category values:
   general, account_access, coaching, organisation, training_tournament,
   location, technical_support, partnership, feedback, other.
5. Submit to the public API endpoint from Phase 1.
6. Map server validation errors to fields.
7. Prevent duplicate submissions while pending.
8. Show clear success, failure and retry states.
9. Include a privacy notice. Ask users not to include passwords, payment details,
   private information about minors, medical details or sensitive player/coach data.
10. Make the form accessible and mobile-friendly.

Turnstile:
- Use VITE_TURNSTILE_SITE_KEY only for the public site key.
- Never include the Turnstile secret in Vite config or browser code.
- Send the response token to the backend for Siteverify.
- Handle expiry, reset and verification failure.
- Do not bypass verification in production.

Test:
- Public route without login.
- Required fields and invalid email.
- Category selection.
- Successful submission.
- API validation and network errors.
- Pending/duplicate submission behavior.
- Turnstile token handling.
- Accessible labels and keyboard interaction.
- Mobile layout.

Run relevant tests, lint and production build. Do not change unrelated navigation or authentication behavior.
```

> **Implemented:** ✅ See [PHASE_03_PUBLIC_CONTACT_PAGE.md](PHASE_03_PUBLIC_CONTACT_PAGE.md). Files: `src/pages/Contact.tsx` (+ tests), `src/services/turnstile.ts`, `src/components/TurnstileWidget.tsx`, `src/constants/contactTypes.ts`, `src/api.ts`, `src/App.tsx`, `src/components/Sidebar.tsx`, `src/vite-env.d.ts`, `src/App.css`, `.env.example`.
>
> **Placement decision:** this application has **no About page**, so the plan's "before About" rule cannot apply. Contact was added as a top-level public navigation link alongside Home / Tournaments / Training Sessions, documented in `Sidebar.tsx` and in the phase file.
>
> **Signed-in refinement:** a visitor with an active session sees their account e-mail as read-only text (with the note "We reply to the email address on your account") and it is sent as the message's `email`; only signed-out visitors see the editable field. The API contract is unchanged — it still validates whatever address arrives.

## Phase 4 — Internal Contact Messages inbox

**Repository:** `beachvolleyballhub_frontend`

### Tasks
1. Add Settings → Contact Messages navigation item.
2. Restrict visibility to authorized platform Admins/Curators.
3. Add protected inbox route and route guard.
4. Build paginated inbox.
5. Add search and filters.
6. Build message detail view.
7. Add read/unread/archive actions.
8. Add unread count using existing notification/navigation patterns where appropriate.
9. Add loading, empty, error and responsive states.
10. Add frontend tests.

### Acceptance criteria
- Only authorized platform Admins/Curators see and access the inbox.
- Organization-only Curators and Coaches do not gain access by default.
- Backend authorization remains authoritative.
- List is newest first and paginated.
- Search and filters work together.
- Message detail displays content safely as plain text.
- Status actions update UI after server confirmation.
- Archived messages are excluded from unread count.
- Unauthorized users receive normal forbidden behavior.
- Mobile layout remains usable.

### AI prompt

```text
Implement Phase 4 of the BeachVolleyballHub Contact feature in the React/Vite frontend repository.

Reuse existing Settings navigation, permission checks, API client, list/table,
pagination, filtering, detail, toast and notification patterns.

Add Settings → Contact Messages.

Implement:
- Protected inbox route.
- Visibility for authorized platform Admins/Curators only.
- Paginated newest-first list.
- Search by sender name, email and subject.
- Filters for unread, read, archived and contact type.
- Message detail view.
- Mark read, mark unread and archive actions.
- Unread count in Settings if consistent with existing UI.
- Loading, empty, error and retry states.
- Responsive desktop/mobile UI.

Use protected API endpoints from Phase 1. Frontend role checks are not the only
security control.

Message content must be displayed as escaped plain text, never interpreted HTML.

Status changes must be confirmed by API before success is shown. Handle stale data,
failed requests and repeated actions safely.

Tests:
- Platform Admin/Curator access.
- Organization-only Curator, Coach, Player/Reader and anonymous access denied.
- List pagination, filters and search.
- Detail display and escaping.
- Read/unread/archive actions.
- Unread count behavior.
- Loading, empty and error states.

Run tests, lint and production build. Do not implement reply, permanent delete
or attachment functionality.
```

> **Implemented:** ✅ See [PHASE_04_INTERNAL_INBOX.md](PHASE_04_INTERNAL_INBOX.md). Files: `src/pages/settings/ContactMessages.tsx` (+ tests), `src/pages/settings/ContactMessageDetail.tsx` (+ tests), `src/App.tsx` (`PlatformStaffRoute` + routes), `src/components/Sidebar.tsx` (+ tests), `src/pages/settings/SettingsDashboard.tsx`, `src/api.ts`.
>
> The inbox is guarded by a new `PlatformStaffRoute` (curator **or** admin) rather than `AdminRoute`, because Curators answer support mail. The API policy remains the authority.

## Phase 5 — Turnstile, abuse protection, integration and release

**Repositories:** API and frontend

### Tasks
1. Verify production Turnstile site/secret configuration for `beachvolleyballhub.com`.
2. Implement or confirm server-side Siteverify.
3. Configure Rails rate limits and trusted proxy handling.
4. Verify Rack::Attack middleware is enabled in production.
5. Implement and test honeypot behavior.
6. Verify request size and input limits.
7. Test email and notification failure behavior.
8. Verify role and account-scope authorization across all endpoints.
9. Run API and frontend test suites.
10. Test complete flow in staging.
11. Document Cloudflare, Render, worker and frontend environment variables.
12. Document deployment, migration, rollback and operational checks.

### Acceptance criteria
- Production submissions require successful server-side Turnstile verification.
- Rate limits return HTTP 429 safely.
- Proxy IP handling is correct for actual Render/Cloudflare topology.
- Honeypot and malformed requests are handled safely.
- No secret is exposed in frontend assets or logs.
- Email and notification failures are observable and do not lose messages.
- Only authorized platform staff can access message content.
- Existing profile, organization, training, tournament, assessment, analysis and weather permissions remain unchanged.
- Complete staging flow passes.
- Existing authentication, notification and email delivery continue to work.

### AI prompt

```text
Complete Phase 5 for the BeachVolleyballHub Contact feature across both repositories.

First inspect current deployment and security controls. Do not assume proxy or hosting
configuration.

Security:
- Verify Cloudflare Turnstile server-side using the secret environment variable.
- Validate expected hostname/action where configured.
- Reject missing, invalid, expired and replayed tokens.
- Verify Rack::Attack middleware is active in production.
- Suggested initial limits: 5 submissions per IP per 10 minutes and 20 per IP per day;
  make configurable if this matches project conventions.
- Verify trusted proxy configuration before using forwarded client IP headers.
- Add and test a honeypot.
- Enforce request and field size limits.
- Ensure HTML, email headers, SQL and logs are safe.
- Confirm no public route exposes ContactMessage records.

Authorization and privacy:
- Test platform Admin/Curator authorization and organization-scoped role boundaries.
- Confirm Coaches and ordinary users cannot read the inbox.
- Confirm this feature does not expose or modify PlayerProfile, CoachProfile,
  Organization, TrainingSession, Tournament, Assessment or Analysis data.
- Confirm message content is not leaked in public APIs, analytics or routine logs.

Integration:
- Test public submission and database persistence.
- Test email delivery to all configured recipients.
- Test platform Admin/Curator notifications.
- Test inbox access and status transitions.
- Test failed email/notification jobs and retries.
- Test rate limiting and Turnstile failures.
- Verify existing BeachVolleyballHub authentication, notifications and mail features
  are unaffected.

Deployment:
- Document Cloudflare widget hostname configuration.
- Document frontend public site key and API secret configuration.
- Document Render API and background worker variables and job processing.
- Verify API CORS allows the production frontend origin.
- Verify production API base URL and health checks.
- Include database migration and rollback steps.
- Do not print secrets in logs or documentation.

Run all relevant API/frontend tests, linters and production builds. Report exact results,
remaining risks and manual production configuration steps.
```

> **Implemented:** ✅ See [PHASE_05_SECURITY_INTEGRATION_RELEASE.md](PHASE_05_SECURITY_INTEGRATION_RELEASE.md). Files: `app/services/turnstile_verifier.rb` (+ tests), `config/initializers/rack_attack.rb`, `.env.example` (API + frontend), `beachvolleyballhub_api/render.yaml`, `DEPLOYMENT_CONFIG.md`.
>
> Results: contact API suite `94 runs / 349 assertions / 0 failures`; full API suite `1928 runs / 0 errors` with 2 pre-existing failures unrelated to this feature; contact frontend suite `54 tests` passing; `npm run build` and RuboCop on all changed files clean. **Operator steps still required:** set `TURNSTILE_SECRET_KEY` and `CONTACT_NOTIFICATION_EMAILS` on the API (and the recipient list on `bvb-api-worker`), and set `VITE_TURNSTILE_SITE_KEY` in the frontend build.

---

# 8. API contract proposal

Adapt exact paths and response envelopes to the existing API.

## Public submission

`POST /api/v1/contact_messages`

Example request:

```json
{
  "contact_message": {
    "name": "Jordan Smith",
    "email": "jordan@example.com",
    "contact_type": "coaching",
    "subject": "Question about coaching sessions",
    "message": "I would like more information about the available sessions.",
    "turnstile_token": "TOKEN",
    "website": ""
  }
}
```

`website` is an example honeypot field. Use the actual field name selected by implementation. Do not persist it.

Successful response should be minimal, for example:

```json
{
  "message": "Your message has been received."
}
```

Use the application's established status code convention (commonly `201 Created`).

## Protected inbox list

`GET /api/v1/admin/contact_messages?status=unread&contact_type=coaching&search=jordan&page=1&per_page=20`

Return paginated records and metadata using the existing API envelope.

List fields:
- id
- name
- email
- contact_type
- subject
- status
- created_at
- read_at
- archived_at

Do not include the full message body in every list row unless existing API conventions require it.

## Protected detail

`GET /api/v1/admin/contact_messages/:id`

Return authorized detail fields, including the full plain-text message.

## Protected update

`PATCH /api/v1/admin/contact_messages/:id`

Example:

```json
{
  "contact_message": {
    "status": "archived"
  }
}
```

Only permit status. Do not permit client changes to sender identity, message content, timestamps or delivery metadata.

---

# 9. Environment variables and deployment

Confirm exact naming and conventions during Phase 0.

| Variable | Where | Purpose |
|---|---|---|
| `CONTACT_NOTIFICATION_EMAILS` | Rails API / Render | Comma-separated delivery recipients |
| `MAIL_REPLY_TO` | Rails API / Render | Preserve existing application meaning; inspect before modifying |
| Existing mail sender/provider variables | Rails API / Render | Use current mail delivery configuration |
| `TURNSTILE_SECRET_KEY` | Rails API / Render | Server-side Siteverify |
| `VITE_TURNSTILE_SITE_KEY` | Frontend build / Cloudflare | Public Turnstile site key |
| Existing API base URL variable | Frontend build / Cloudflare | Production API URL; preserve current naming |

### Cloudflare configuration
1. Create or reuse a Turnstile widget.
2. Add `beachvolleyballhub.com` and any actual production frontend hostnames.
3. Add staging hostname(s) if staging is used.
4. Configure the public site key in the frontend build environment.
5. Configure the secret only in the API hosting environment.
6. Confirm API can reach Cloudflare Siteverify.
7. Never commit either key to source control.

### Render/API configuration
- Set API variables in the Render API service.
- Confirm the production background worker uses the same required environment and queue configuration.
- Confirm the worker is deployed and processing email/notification jobs.
- Run database migration as part of controlled deployment.
- Verify health checks and job monitoring.
- Verify CORS allows the production frontend origin.
- Verify `api.beachvolleyballhub.com` and current API base URL configuration.

### Cloudflare frontend configuration
- Set `VITE_TURNSTILE_SITE_KEY` in the frontend build environment and rebuild.
- Ensure the frontend API base URL points to `https://api.beachvolleyballhub.com` (or the verified production API URL).
- Do not put API secrets in Cloudflare public variables or any `VITE_` variable.
- Confirm Cloudflare WAF/rate-limit settings complement Rails-side controls.

### Database
- Use the configured production PostgreSQL/Neon database.
- Confirm migration compatibility and backup/rollback procedure.
- Do not introduce a second database or a separate storage system for this feature.

---

# 10. Testing checklist

## Model and API
- [ ] Valid message is persisted.
- [ ] Missing name/email/type/subject/message rejected.
- [ ] Invalid email rejected.
- [ ] Unsupported contact type rejected.
- [ ] Maximum lengths enforced.
- [ ] Malformed payload rejected.
- [ ] Public create response does not expose internal fields.
- [ ] Anonymous list/detail/update denied.
- [ ] Player/Reader and Coach list/detail/update denied.
- [ ] Organization-scoped Curator cannot access platform inbox unless explicitly authorized.
- [ ] Platform Admin and authorized Curator list/detail/update allowed.
- [ ] Search and filters return correct results.
- [ ] Pagination is bounded.
- [ ] Sorting uses an allowlist.
- [ ] Status timestamps remain consistent.

## Email and notifications
- [ ] Every configured recipient receives an email.
- [ ] Recipient parsing trims whitespace and removes duplicates.
- [ ] Invalid recipient configuration is handled safely.
- [ ] Existing `MAIL_REPLY_TO` behavior is preserved.
- [ ] Sender is not used as the From address.
- [ ] Sender is used as Reply-To where supported.
- [ ] HTML email escapes user content.
- [ ] Plain-text email is readable.
- [ ] Email delivery failure does not delete the message.
- [ ] All active platform Admins/Curators are notified.
- [ ] Coaches, organization-only Curators and inactive users are excluded unless explicitly authorized.
- [ ] Retries do not duplicate notifications.
- [ ] Production worker processes jobs.

## Frontend
- [ ] Contact appears in correct public menu position.
- [ ] Contact route is public.
- [ ] Form works on desktop and mobile.
- [ ] Required field and email validation work.
- [ ] Category options match backend allowlist.
- [ ] Pending state prevents duplicate clicks.
- [ ] Success only appears after API confirmation.
- [ ] API errors are displayed safely.
- [ ] Turnstile expiry/reset is handled.
- [ ] Contact Messages appears under Settings for authorized staff only.
- [ ] Other roles cannot access route.
- [ ] Search, filters and pagination work.
- [ ] Message content is rendered as text.
- [ ] Read/unread/archive actions work.
- [ ] Archived messages do not inflate unread count.

## Abuse and operational checks
- [ ] Turnstile success accepted.
- [ ] Invalid/expired/missing Turnstile token rejected.
- [ ] Production verification fails closed.
- [ ] Rate limit returns 429.
- [ ] Rack::Attack middleware activation confirmed.
- [ ] Proxy IP handling verified.
- [ ] Honeypot behavior works.
- [ ] Request size limits work.
- [ ] No secrets in frontend bundle.
- [ ] No message bodies in routine logs.
- [ ] Job failures are observable.
- [ ] Staging end-to-end flow passes.

## Regression and domain privacy
- [ ] Existing authentication and registration still work.
- [ ] Existing notification badge and notification links still work.
- [ ] Existing email flows still work.
- [ ] Player/Coach profile privacy is unchanged.
- [ ] Organization membership authorization is unchanged.
- [ ] Training sessions and schedules remain protected.
- [ ] Tournament, assessment and analysis permissions are unchanged.
- [ ] Location privacy is unchanged.
- [ ] Weather and public map features are unaffected.

---

# 11. Staging acceptance walkthrough

1. Open the BeachVolleyballHub frontend in a private/incognito browser.
2. Confirm Contact appears in the intended public navigation position.
3. Open Contact without logging in.
4. Submit a valid general enquiry.
5. Confirm a success message appears.
6. Confirm one database record exists.
7. Confirm every configured recipient receives the email.
8. Confirm active platform Admins/Curators receive an in-app notification.
9. Sign in as an ordinary Player/Reader and verify Contact Messages is not available and API access is forbidden.
10. Sign in as a Coach and verify inbox access is forbidden.
11. If organization-scoped Curator roles exist, verify they cannot access the platform inbox unless explicitly authorized.
12. Sign in as an authorized platform Curator/Admin and open Settings → Contact Messages.
13. Search for the submitted sender and subject.
14. Open the message and verify content is displayed safely.
15. Mark it unread, then read, then archive it.
16. Confirm unread count and archived filter behave correctly.
17. Test invalid Turnstile, honeypot and rate-limited submissions.
18. Verify failed email delivery does not remove the message and can be retried.
19. Verify the Render background worker processes queued jobs.
20. Verify existing profile, organization, training, tournament, assessment, analysis and notification workflows remain unaffected.

---

# 12. Release and rollback plan

## Release order
1. Complete Phase 0 audit.
2. Implement and deploy API migration/endpoints.
3. Configure recipient and Turnstile secrets on Render API.
4. Confirm background worker deployment and queue processing.
5. Deploy frontend with public Contact page and protected inbox.
6. Enable public navigation entry.
7. Run staging acceptance walkthrough.
8. Verify production recipients, CORS, Turnstile and job processing.
9. Monitor submissions, delivery failures, 429s and Turnstile failures after release.

## Rollback
- Prefer removing/hiding frontend exposure first if public submissions cause problems.
- Keep already persisted contact messages; do not drop the table during rollback.
- If API code must be rolled back, ensure the database migration remains backward-compatible with the prior application version.
- Do not remove or rotate shared mail/Turnstile settings in a way that breaks other application features.
- Re-enable the feature only after the failure is understood and tested.

---

# 13. Explicitly out of scope

Do not implement these in the initial task:
- Replying to messages inside BeachVolleyballHub.
- Conversation threads.
- Attachments or video uploads.
- Ticket assignment or ownership.
- Priority/severity workflows.
- CRM integrations.
- Automatic message deletion.
- Public message lookup.
- Automatic conversion to PlayerProfile, CoachProfile, Organization, TrainingSession or Tournament records.
- New roles or a new notification framework.
- A new email provider.
- Changes to existing player/coach privacy or organization permission rules.

These can be considered later based on actual usage.

## Definition of done

The task is complete when a visitor can submit a secure public enquiry, the message is reliably stored, configured recipients receive an email, authorized platform Admins/Curators receive an in-app notification, and authorized staff can manage messages through Settings → Contact Messages — with automated tests, deployment documentation and a successful staging walkthrough.

All existing BeachVolleyballHub authorization and privacy boundaries for player/coach profiles, organizations, training, tournaments, assessments, analysis and locations must remain intact.
