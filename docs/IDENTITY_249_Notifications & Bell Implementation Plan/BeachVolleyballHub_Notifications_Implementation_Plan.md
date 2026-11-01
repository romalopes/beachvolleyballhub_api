# Beach Volleyball Hub — Notifications & Bell Implementation Plan

**Date:** 2026-11-01  
**Status:** Implemented — see §0 for per-phase status and report links; email, follows and push are deferred by design  
**Repositories:**
- Wine Words Rails API: https://github.com/romalopes/wine_words_api
- Wine Words React frontend: https://github.com/romalopes/wine_words_frontend
- Beach Volleyball Hub Rails API: https://github.com/romalopes/beachvolleyballhub_api
- Beach Volleyball Hub React frontend: https://github.com/romalopes/beachvolleyballhub_frontend

> **Verification note:** This plan is based on the described applications and intended Wine Words parity. The repository contents have not been verified in this session. Phase 0 is mandatory: inspect the current source and replace proposed names and routes with actual conventions before editing. Do not claim that specific files or gems already exist without inspecting them.

## 0. Implementation status (updated 2026-11-01)

The plan has been implemented. Phase 0 was executed against the local repositories and corrected
several of this document's assumptions (Rails 8.1 / **Minitest**, not RSpec; **custom CSS**, not
Bootstrap; **no TanStack Query**; `solid_queue` already installed). Each phase has its own report:

| Phase | Topic | Status | Report |
|---|---|---|---|
| 0 | Audit and Wine Words parity mapping | ✅ Complete | [PHASE_00_AUDIT_AND_PARITY_MAPPING.md](PHASE_00_AUDIT_AND_PARITY_MAPPING.md) |
| 1 | Data model and migrations | ✅ Complete | [PHASE_01_DATA_MODEL_AND_MIGRATIONS.md](PHASE_01_DATA_MODEL_AND_MIGRATIONS.md) |
| 2 | Backend API | ✅ Complete | [PHASE_02_BACKEND_API.md](PHASE_02_BACKEND_API.md) |
| 3 | Domain events and recipients | ✅ Complete | [PHASE_03_DOMAIN_EVENTS_AND_RECIPIENTS.md](PHASE_03_DOMAIN_EVENTS_AND_RECIPIENTS.md) |
| 4 | React bell and inbox | ✅ Complete | [PHASE_04_REACT_BELL_AND_INBOX.md](PHASE_04_REACT_BELL_AND_INBOX.md) |
| 5 | Training + organisations | ✅ Complete | [PHASE_05_TRAINING_AND_ORGANISATIONS.md](PHASE_05_TRAINING_AND_ORGANISATIONS.md) |
| 6 | Tournaments, assessments, analysis, comments | ⏸️ Deferred (audited) | [PHASE_06_TOURNAMENTS_ASSESSMENTS_ANALYSIS_COMMENTS.md](PHASE_06_TOURNAMENTS_ASSESSMENTS_ANALYSIS_COMMENTS.md) |
| 7 | Preferences | ✅ Complete | [PHASE_07_PREFERENCES.md](PHASE_07_PREFERENCES.md) |
| 8 | Email and durable delivery | ⏸️ Deferred (worker gate) | [PHASE_08_EMAIL_AND_DURABLE_DELIVERY.md](PHASE_08_EMAIL_AND_DURABLE_DELIVERY.md) |
| 9 | Follow subscriptions | ⏸️ Deferred (audited) | [PHASE_09_FOLLOW_SUBSCRIPTIONS.md](PHASE_09_FOLLOW_SUBSCRIPTIONS.md) |
| 10 | Browser / PWA push | ⏸️ Deferred (optional) | [PHASE_10_BROWSER_PWA_PUSH.md](PHASE_10_BROWSER_PWA_PUSH.md) |
| 11 | Testing, performance and security | ✅ Complete | [PHASE_11_TESTING_PERFORMANCE_SECURITY.md](PHASE_11_TESTING_PERFORMANCE_SECURITY.md) |
| 12 | Deployment, rollout and rollback | 📋 Runbook produced | [PHASE_12_DEPLOYMENT_ROLLOUT_ROLLBACK.md](PHASE_12_DEPLOYMENT_ROLLOUT_ROLLBACK.md) |

### Delivered MVP A + B (milestones 0–5)

| Layer | Artefacts |
|---|---|
| Schema | `db/migrate/20261101000001_create_notifications.rb` (`notifications`, `notification_preferences`) |
| Models | `app/models/notification.rb`, `app/models/notification_preference.rb`, `app/models/account.rb` associations |
| Services | `app/services/notifications/publisher.rb`, `app/services/notifications/workflow_events.rb` |
| API | `app/controllers/api/v1/notifications_controller.rb`, `app/controllers/api/v1/notification_preferences_controller.rb`, `config/routes.rb` |
| Workflow hooks | `api/v1/training_sessions_controller.rb`, `api/v1/organisations_controller.rb`, `api/v1/groups_controller.rb` |
| Frontend | `src/components/NotificationBell.tsx`, `src/pages/Notifications.tsx`, `src/components/NotificationPreferencesPanel.tsx`, `src/services/notificationEvents.ts`, `src/api.ts`, `src/App.tsx`, `src/components/Sidebar.tsx`, `src/pages/Account.tsx`, `src/App.css` |
| Backend tests | `test/models/notification_test.rb`, `test/models/notification_preference_test.rb`, `test/services/notifications/*`, `test/controllers/api/v1/notifications_controller_test.rb`, `test/controllers/api/v1/notification_preferences_controller_test.rb` |
| Frontend tests | `src/components/NotificationBell.test.tsx`, `src/pages/Notifications.test.tsx`, `src/components/NotificationPreferencesPanel.test.tsx` |

### Verified results

- Backend notification tests: **40 runs, 110 assertions, 0 failures, 0 errors**.
- Frontend notification tests: **27 passed**; `tsc -b`, `eslint`, `npm run build` clean.
- `rubocop` clean on all new/changed files.
- **Zero new test failures** — the 21 backend and 3 frontend failures are pre-existing and were
  proven identical with the change stashed (see Phase 11 §2).

### Not implemented (with reasons)

Email delivery (Phase 8), follows (Phase 9) and push (Phase 10) are **deliberately not enabled**:
each is gated on an operational or product decision this repository cannot make (production worker
verification; privacy design for follows; VAPID/service-worker/consent for push). No job is
enqueued and no permission is requested, so nothing claims to work that does not. See the individual
phase reports for the completion checklists.

## 1. Goals and non-goals

Create a unified, secure, account-scoped notification system that displays an unread badge and dropdown in the Beach Volleyball Hub header, provides a full notifications page, supports mark-read actions, and can later deliver email and browser/PWA push notifications. Start with training and organisation workflows, then expand to tournaments, account claims, assessments, analysis, comments, and subscriptions.

**Non-goals for initial release:** real-time WebSockets, Redis, mobile-native apps, cross-app notification synchronization with Wine Words, generic direct messaging, and automatic propagation through the full organisation hierarchy.

**Core principles:** persistent in-app records are the source of truth; delivery channels are independent; events are idempotent; only authorised recipients see notifications; a notification is not permission to access its target; no new paid infrastructure is required for the first release.

## 2. Infrastructure and dependencies

| Concern | Recommended | Installation / configuration | Cost / notes |
|---|---|---|---|
| Persistent storage | Existing Neon PostgreSQL | Rails migration | No additional service; existing database quotas apply |
| Background jobs | Rails Active Job | Built into Rails | Free; needs an actual worker for durable async execution |
| Queue adapter | `solid_queue` (if compatible with deployment) | `bundle add solid_queue`; verify current Rails configuration | Free gem; may need a continuously running Render process and queue DB configuration |
| Alternative first release | Synchronous DB creation + existing verified mail/job infrastructure | No new worker required for in-app writes | Reliable in-app records; external delivery must use a durable mechanism |
| In-app frontend | Existing React, TypeScript, Bootstrap | Reuse existing project packages | Free |
| Polling | Existing data-fetching hooks, or `@tanstack/react-query` if already used/approved | `pnpm add @tanstack/react-query` only if needed | Free; 30–60s while visible |
| Email | Existing Brevo HTTP adapter | Reuse credentials and existing service | Free tier subject to quotas; do not install SMTP-only dependency |
| Browser push (future) | `web-push` Ruby gem, native Service Worker / Push API | `bundle add web-push`; generate VAPID keys | Free library; browser support/permission constraints apply |
| Tests | RSpec, request specs, Vitest, Testing Library, Playwright | Reuse existing dependencies first | Free |
| Observability | Existing Sentry | Add structured error tags and metrics | Existing quota applies |
| Realtime (deferred) | Action Cable / SSE only if proven necessary | None now | Additional infrastructure/operational complexity |

**Deployment decision gate:** On Render, confirm whether the existing API service runs persistent workers, whether a background worker service is included in the current plan, and whether the Neon pooled connection is appropriate for Solid Queue's connection requirements. Do not assume a free Render web service can host a reliable always-on queue. For v1, save in-app notifications transactionally and defer asynchronous external delivery until a durable worker is confirmed. If Solid Queue is selected, configure worker start command, DB migrations, retries, concurrency, pool sizing, monitoring, and deploy order. Keep job payloads to IDs, not serialized large objects.

**Recommended initial topology:**

```text
Domain event / application service
       |
       v
Notification event dispatcher
       |
       +--> recipient resolver + authorization + deduplication
       |            |
       |            v
       |       PostgreSQL notifications
       |            |
       |            v
       |       Rails notifications API <-- React bell + inbox (polling)
       |
       +--> durable delivery/outbox (when enabled)
                    |
                    +--> Brevo email
                    +--> Web Push (future)
```

Avoid using the browser as the authoritative source of notification state.

## 3. Mandatory Phase 0 — Audit and Wine Words parity mapping

> **Implemented:** ✅ See [PHASE_00_AUDIT_AND_PARITY_MAPPING.md](PHASE_00_AUDIT_AND_PARITY_MAPPING.md) for the verified environment, the Wine Words→BVH parity matrix, and the plan corrections.

### Tasks
1. Checkout/pull all four repositories; record current commit SHAs and framework versions.
2. Search Wine Words backend for `Notification`, notification migrations, controllers, routes, serializers, policy checks, callbacks, jobs, event services, unread count, mark-read and delivery preferences.
3. Search Wine Words frontend for `NotificationBell`, dropdown, hooks, polling, auth context, header integration, navigation and error states.
4. Search Beach Volleyball Hub for existing notification primitives, Account model, RBAC, organisation hierarchy, training registration, tournament participants, invitation/claim workflows, assessments, analysis and comments.
5. Verify existing test conventions, API namespaces, pagination, serializers, `pnpm` scripts, job adapter, Render process configuration, Brevo adapter and Sentry integration.
6. Produce a **parity matrix**: Wine Words path/symbol -> purpose -> Beach Volleyball Hub counterpart -> copy/adapt/reimplement -> tests -> risks.
7. Identify any existing notification implementation before generating migrations; do not duplicate schema or components.

### AI prompt — Audit
```text
You are working across four repositories: wine_words_api, wine_words_frontend,
beachvolleyballhub_api, and beachvolleyballhub_frontend.
Read the actual source code before proposing edits. Locate the complete Wine Words
notification/bell implementation (models, migrations, routes, controllers, services,
jobs, mailers, frontend components/hooks, tests) and inspect the relevant BVH code.
Report exact file paths, API contracts, current behavior, dependencies, permission
checks, missing features, and differences. Build a parity matrix and an ordered
migration plan. Do not implement yet. Flag uncertainty instead of guessing.
```

**Exit criteria:** exact implementation map, confirmed API naming, deployment feasibility, and documented compatibility decisions.

## 4. Data model and migrations — Phase 1

> **Implemented:** ✅ See [PHASE_01_DATA_MODEL_AND_MIGRATIONS.md](PHASE_01_DATA_MODEL_AND_MIGRATIONS.md) — `db/migrate/20261101000001_create_notifications.rb`, `app/models/notification.rb`, `app/models/notification_preference.rb`.

### 4.1 `notifications`

Suggested fields (adapt to Wine Words if already proven):

| Column | Type | Rule |
|---|---|---|
| `id` | bigint/uuid | Follow project primary key convention |
| `account_id` | foreign key | Required recipient, indexed |
| `actor_id` | foreign key to accounts | Nullable for system-generated events |
| `event_type` | string | Required, namespaced (`training_session.cancelled`) |
| `notifiable_type`, `notifiable_id` | polymorphic reference | Nullable for system-wide events |
| `title` | string | Short, non-sensitive snapshot |
| `body` | text | Sanitized, non-sensitive summary |
| `action_path` | string | Internal relative path only, validated |
| `metadata` | jsonb | Minimal immutable context, no secrets |
| `read_at` | datetime | Null = unread |
| `dismissed_at` | datetime | Optional soft-dismiss |
| `dedupe_key` | string | Stable per recipient/event; unique |
| `created_at`, `updated_at` | datetime | Rails timestamps |

Indexes: `(account_id, created_at DESC)`, partial `(account_id, created_at DESC) WHERE read_at IS NULL AND dismissed_at IS NULL`, unique `(account_id, dedupe_key)`; add target reference index if reverse lookup is needed. Foreign keys for recipient/actor, cascading or safe deletion policy consistent with account deletion.

**Important:** polymorphic `notifiable` does not automatically enforce a database FK; handle missing/deleted targets gracefully. Use an event snapshot so notification history remains readable. `action_path` must not accept arbitrary external URLs.

### 4.2 `notification_preferences` (Phase 7)

`account_id`, `category`, `in_app_enabled`, `email_enabled`, `push_enabled`, `created_at`, `updated_at`; unique `(account_id, category)`. Alternative JSONB preferences are acceptable if Wine Words already has a robust schema. Mandatory operational notifications cannot be suppressed where business requirements demand delivery; define categories and defaults explicitly.

### 4.3 `notification_deliveries` / outbox (Phase 8)

Store per-channel delivery state: `notification_id`, `channel`, `status`, `attempts`, `next_attempt_at`, `sent_at`, `last_error`, `provider_message_id`, timestamps; unique `(notification_id, channel)`. Retry safely with idempotency where the provider permits it. Separate DB persistence from email/push transport.

### 4.4 `push_subscriptions` (Phase 10)

`account_id`, `endpoint` (encrypted where possible), `p256dh`, `auth`, `user_agent`, `last_used_at`, timestamps; unique endpoint digest; remove expired/410 subscriptions. Never expose other accounts' subscription credentials.

### AI prompt — Schema
```text
Using the verified Wine Words schema and the existing BVH Account model, implement
minimal notification persistence for BVH. Match existing naming conventions and
API serialization. Add account-scoped associations, event_type, polymorphic target,
actor, safe action path, metadata, read_at, dedupe_key, and necessary indexes.
Preserve existing tables; do not create duplicates. Write model and migration specs,
including concurrent duplicate insertion, account deletion, missing target,
and unread queries. Run migrations and tests; report all files changed.
```

**Exit criteria:** migration reversible, indexed unread queries, recipient isolation, duplicate prevention.

## 5. Backend API — Phase 2

> **Implemented:** ✅ See [PHASE_02_BACKEND_API.md](PHASE_02_BACKEND_API.md). Actual routes are `/api/v1/notifications`, `/api/v1/notifications/unread_count`, `/api/v1/notifications/:id/mark_read`, `/api/v1/notifications/mark_all_read`, `/api/v1/notification_preferences` (the plan's `/api/notifications/...` examples were namespace-corrected to the project's `/api/v1` convention).

Proposed endpoints; use verified existing namespace and patterns:

| Method | Route | Behavior |
|---|---|---|
| GET | `/api/notifications` | Authenticated, cursor/paginated, filter `all/unread`, newest first |
| GET | `/api/notifications/unread_count` | Efficient count for current account |
| PATCH | `/api/notifications/:id/read` | Idempotent mark-read, own notification only |
| PATCH | `/api/notifications/read_all` | Mark all own visible notifications read |
| PATCH | `/api/notifications/:id/dismiss` | Optional hide without destroying audit data |
| GET/PATCH | `/api/notification_preferences` | Later phase |

Return stable response shape with ID, event type, title, body, action path, actor summary if visible, created/read state and pagination metadata. Authenticate every endpoint. Always scope queries through `current_account.notifications`; never trust `account_id` supplied by the client. Recheck target authorization when navigating. Rate-limit abuse-prone operations and bound page sizes.

### AI prompt — API
```text
Implement authenticated notification API endpoints following the actual BVH
controller, serializer, auth and pagination conventions. Never accept a recipient
account ID from the client. Provide list, unread_count, mark-read, mark-all-read,
and optional dismiss endpoints. Ensure missing or unauthorized IDs do not reveal
another user's notification. Add request specs for unauthenticated, cross-account,
pagination, unread filtering, idempotency, and deleted targets. Run the suite.
```

## 6. Domain events and recipients — Phase 3

> **Implemented:** ✅ See [PHASE_03_DOMAIN_EVENTS_AND_RECIPIENTS.md](PHASE_03_DOMAIN_EVENTS_AND_RECIPIENTS.md) — `Notifications::Publisher` (dispatcher) and `Notifications::WorkflowEvents` (recipient rules).

Use a single event registry and a `Notifications::RecipientsResolver` (names provisional) with event-specific resolver classes or handlers. Trigger from domain services / completed transactions rather than scattering `after_save` callbacks across models. Publish only meaningful transitions; compare old/new values for rescheduling and cancellation. Avoid emitting events for seed imports, no-op updates or bulk maintenance.

### Event matrix

| Event type | Recipients | Priority | Notes |
|---|---|---|---|
| `training_session.created` | Eligible group subscribers | P2 | Not all organisation members |
| `training_session.rescheduled` | Registered participants | P1 | Date/time diff only |
| `training_session.cancelled` | Registered participants | P1 | Email candidate |
| `training_session.location_changed` | Registered participants | P1 | Include safe new location |
| `training_registration.created` | Coach / session manager | P2 | Exclude actor |
| `training_registration.cancelled` | Coach / session manager | P2 | Exclude actor |
| `training_session.reminder` | Registered participants | P1 | Schedule only if worker available |
| `organisation.membership_requested` | Authorized approvers | P1 | RBAC scoped |
| `organisation.membership_approved` | Applicant | P1 | No broad broadcast |
| `organisation.membership_rejected` | Applicant | P1 | Avoid exposing sensitive reason |
| `organisation.invitation_created` | Invitee | P1 | Email may be separate invitation mail |
| `account_claim.requested` | Authorized reviewers | P1 | Prevent account takeover |
| `account_claim.approved` | Claimant | P1 | Re-check identity |
| `tournament.registration_confirmed` | Participant | P1 | Verify participation |
| `tournament.schedule_changed` | Registered participants | P1 | Diff only |
| `tournament.cancelled` | Registered participants | P1 | Email candidate |
| `assessment.shared` | Authorized evaluated player | P1 | No scores in preview |
| `analysis.requested` | Assigned coach | P2 | Future integration |
| `analysis.completed` | Requester / authorized player | P1 | Privacy check |
| `comment.created` | Relevant owner/subscribers | P2 | Avoid loops/spam |
| `comment.replied` | Parent commenter | P2 | Exclude actor |
| `announcement.published` | Explicit audience | P2 | Controlled fanout |

**P1** = transactional; **P2** = optional/subscription-based. Use role and organisation membership at event time; verify target access again at click time. Do not automatically notify international/national/state parents about every club/group activity.

### AI prompt — Dispatcher
```text
Implement a centralized notification event dispatcher and recipient resolver for
BVH using actual existing domain models. Start with training rescheduled/cancelled
and organisation membership requested/approved. Generate notifications only after
successful domain commits. Exclude the actor, deduplicate recipients, use stable
event keys, respect tenant scope/RBAC, and avoid N+1 queries. Do not send email yet.
Add unit and integration specs for authorization, recipient selection, no-op edits,
rollback, retries, and concurrency. Do not notify unrelated parent organisations.
```

## 7. React bell and inbox — Phase 4

> **Implemented:** ✅ See [PHASE_04_REACT_BELL_AND_INBOX.md](PHASE_04_REACT_BELL_AND_INBOX.md). Actual files differ from the provisional list: `src/components/NotificationBell.tsx`, `src/pages/Notifications.tsx`, `src/components/NotificationPreferencesPanel.tsx`, `src/services/notificationEvents.ts` (types live in `src/api.ts`, matching the project convention).

Reuse Wine Words UX where compatible. Suggested files, subject to audit:

```text
src/components/notifications/NotificationBell.tsx
src/components/notifications/NotificationDropdown.tsx
src/components/notifications/NotificationItem.tsx
src/pages/Notifications.tsx
src/hooks/useNotifications.ts
src/services/notifications.ts
src/types/notification.ts
```

- Show bell only for authenticated accounts in existing desktop/mobile header.
- Unread badge: `0` hidden, cap display at `99+`.
- Dropdown: 5–10 recent notifications; link to full inbox.
- Inbox: paginated all/unread filters, mark-read, mark-all, empty/loading/error states.
- Clicking notification: mark read then navigate through validated internal route; if target deleted or inaccessible, show a friendly unavailable message.
- Poll unread count every 30–60 seconds **only when authenticated and visible**, refresh on focus/reconnect and after mutations. Pause on logout; clear account-specific cache on account change.
- Respect reduced-motion, keyboard navigation, focus management, aria-labels, screen-reader unread announcements, touch targets, mobile drawer/responsive navigation.
- Use TanStack Query only if already installed or useful; avoid introducing a duplicate fetching stack.

### AI prompt — Frontend
```text
Inspect Wine Words notification bell, dropdown, hooks, CSS, API adapter and tests,
then adapt the UX to the existing BVH React/TypeScript app without disrupting
navigation. Reuse BVH auth state, HTTP client and design system. Add unread polling
(30–60s while visible), list/inbox, mark-read and mark-all actions, safe navigation,
mobile responsive behavior and accessible keyboard support. Do not add a second
state-management or query library if one already exists. Add Vitest/Testing Library
and Playwright coverage for badge, auth/logout, failures and mobile layouts.
```

## 8. Domain rollout — Phases 5–6

### Phase 5 — Training + organisations

> **Implemented:** ✅ See [PHASE_05_TRAINING_AND_ORGANISATIONS.md](PHASE_05_TRAINING_AND_ORGANISATIONS.md). Registration/claim events were not applicable or were deferred (that report explains why).

Implement and test training cancellation/rescheduling/location changes, registration notifications, membership requests/approvals, invitations and account claim reviews. Use actual domain service boundaries and event transition semantics. Handle recurring training: single occurrence vs series changes; generate one notification per affected event/recipient rather than duplicates.

**AI prompt:**
```text
Wire the verified dispatcher into BVH training, recurring training, registration,
organisation membership and account-claim workflows. Identify existing service
entry points first. Emit events only for committed, meaningful state transitions;
ensure correct recipients and authorization. Test single-session vs recurring-series
changes, canceled registrations, approver permissions, and repeated updates.
```

### Phase 6 — Tournaments, assessments, analysis, comments

> **Deferred:** ⏸️ See [PHASE_06_TOURNAMENTS_ASSESSMENTS_ANALYSIS_COMMENTS.md](PHASE_06_TOURNAMENTS_ASSESSMENTS_ANALYSIS_COMMENTS.md). The plan's own instruction to defer unimplemented features rather than add speculative callbacks was followed; the audit records which events exist and what decision each needs.

Add tournament registration/schedule/result events, assessment shared, analysis requested/completed, comment/reply events. Only notify players when sharing/visibility conditions are met. Do not put private assessment details in title/body/push/email. Defer events for unimplemented features rather than adding speculative callbacks.

**AI prompt:**
```text
Extend the notification registry for existing BVH tournament, assessment, analysis
and comment workflows. Before coding, verify which entities and transitions really
exist. Resolve recipients using actual permissions and relationships. Ensure
assessment/analysis content is never leaked in previews. Add domain request specs,
privacy specs and deduplication tests. Do not create placeholder business entities.
```

## 9. Preferences — Phase 7

> **Implemented:** ✅ See [PHASE_07_PREFERENCES.md](PHASE_07_PREFERENCES.md) — `notification_preferences`, `GET|PATCH /api/v1/notification_preferences`, `src/components/NotificationPreferencesPanel.tsx`, enforced in `Notifications::Publisher`.

Introduce notification categories: `training`, `tournaments`, `membership`, `profiles`, `assessments`, `analysis`, `comments`, `announcements`. Store per-account channel settings. Default in-app transactional notifications on; email off for low-priority events; push off until explicit opt-in. Distinguish mandatory service/operational communications from optional follows. Enforce preferences server-side when planning channel deliveries.

**AI prompt:**
```text
Implement account-scoped notification preferences with category/channel defaults.
Reuse Wine Words conventions if compatible. Provide authenticated GET/PATCH API and
settings UI. Preserve mandatory operational notifications where appropriate.
Test preference persistence, cross-account isolation, defaults and behavior of
delivery planning when channels are disabled.
```

## 10. Email and durable delivery — Phase 8

> **Deferred:** ⏸️ See [PHASE_08_EMAIL_AND_DURABLE_DELIVERY.md](PHASE_08_EMAIL_AND_DURABLE_DELIVERY.md). The deployment gate in this section was honoured: the outbox columns and `email_enabled`/`email_cadence` preferences are in place, but **no email is enqueued** until a production Solid Queue worker is verified.

Reuse existing Brevo HTTP adapter, verified sender identity, and templating conventions. Email only high-value events first (cancellation, reschedule, invitation, membership decision). Use outbox/delivery rows and durable background jobs to retry transient failures. Configure exponential backoff, bounded attempts, dead-letter/manual retry visibility, provider rate limits, and suppression for bounced/unsubscribed addresses. Ensure notification creation succeeds even when Brevo is unavailable. Send from verified domain; never expose private details in subject/preheader.

**Deployment gate:** if no reliable worker is available on the current Render plan, keep email phase disabled rather than silently losing jobs. Consider a paid worker only after confirming costs and requirements; no new paid service is necessary for the initial in-app bell.

**AI prompt:**
```text
Inspect existing BVH Brevo HTTP delivery and current Active Job adapter. Implement
idempotent notification email delivery via a durable outbox and worker only after
verifying production worker availability. Start with cancellation/reschedule and
membership decisions. Use existing sender settings and templates. Add retries,
status tracking, provider error handling, preference enforcement and tests with
mocked HTTP; never perform external HTTP calls inside DB transactions.
```

## 11. Follow subscriptions — Phase 9

> **Deferred:** ⏸️ See [PHASE_09_FOLLOW_SUBSCRIPTIONS.md](PHASE_09_FOLLOW_SUBSCRIPTIONS.md). The audit found an existing `TournamentFollow`, so a generic polymorphic `follows` table was **not** added (it would duplicate an existing concept and risk shadow membership).

Introduce a separate polymorphic `follows` table if it does not already exist: `account_id`, `followable_type`, `followable_id`, timestamps, unique `(account_id, followable_type, followable_id)`. Followable candidates: Organisation, Group, CoachProfile, TrainingSession, Tournament (possibly PlayerProfile only after explicit privacy design). Following is **not** organisation membership and is **not** needed for transactional events. Prevent private-entity follows and validate follow permissions on both subscribe and dispatch.

**AI prompt:**
```text
Add a polymorphic Follow feature only after auditing existing follow/member models.
Implement follow/unfollow for allowed public or authorised entities, unique records,
permission checks and UI. Feed optional notification recipients into the central
resolver, without replacing transactional recipients. Do not equate following with
organisation membership. Test visibility, duplicate follows and unfollow behavior.
```

## 12. Browser / PWA push — Phase 10 (optional)

> **Deferred:** ⏸️ See [PHASE_10_BROWSER_PWA_PUSH.md](PHASE_10_BROWSER_PWA_PUSH.md). Prerequisites are absent (the service worker is a placeholder, no `web-push`/VAPID/subscription storage), and push depends on the Phase 8 durable-delivery gate.

Use native browser Push API, Notifications API and Service Worker plus Ruby `web-push` with VAPID. HTTPS is required in production. Ask for permission only after an explicit user action in settings; do not prompt at initial page load. Store multiple subscriptions per account/device, support opt-out/logout cleanup, handle expired subscriptions, validate push payload size, and deep-link to safe internal routes. Test desktop Chromium/Firefox and mobile support separately; iOS web push requires supported installed web-app behavior and user permission. Never promise delivery or background reliability across all browsers.

**AI prompt:**
```text
Add optional browser/PWA push without changing the in-app notification source of
truth. Verify current BVH PWA/service-worker setup first. Implement VAPID keys,
secure subscription endpoints, encrypted/safe subscription storage, explicit
permission UI, service-worker push handler, deep links and unsubscribing. Deliver
through the existing durable outbox and Rails web-push gem. Test expired endpoints,
unsupported browsers, multiple devices, logout and private-content minimization.
```

## 13. Testing, performance and security — Phase 11 (continuous)

> **Implemented:** ✅ See [PHASE_11_TESTING_PERFORMANCE_SECURITY.md](PHASE_11_TESTING_PERFORMANCE_SECURITY.md) for the exact commands, results, the proof that all remaining failures are pre-existing, the security review and the manual acceptance checklist.

### Backend test matrix
- Model validation, scopes, unread count, partial indexes and unique dedupe key.
- Request specs for authentication, pagination, filters, marking read and cross-account IDOR.
- Recipient resolver: member vs nonmember, active/inactive, hierarchy, role changes, actor exclusion, duplicate recipients.
- Event integration: transaction rollback, no-op update, repeat delivery, recurring session changes, concurrent event creation.
- Outbox/job: retries, worker interruption, transient Brevo errors, preference changes, idempotency.
- Privacy: deleted target, revoked access, assessment visibility, untrusted action path.

### Frontend test matrix
- Bell badge, empty/unread states, dropdown navigation, pagination, mark-read optimistic rollback.
- Polling paused for anonymous/background tabs, focus refresh, cache cleared on logout/account switch.
- Responsive mobile layout, keyboard accessibility, screen reader labels, network failures.
- End-to-end: create training -> recipient bell -> click -> read state; cross-account denial.

### Performance/observability
- Benchmark unread count with realistic notification volume and index usage.
- Use bulk inserts where fanout is large; batch by account and cap payloads.
- Metrics: created per event, unread count latency, delivery success/failure, retry depth, deduped events, API errors.
- Sentry: tag event type and channel, **not** private notification text or user secrets.
- Retention: define purge/archive policy (e.g. read notifications older than 180 days) with user requirements and legal/privacy needs reviewed first.

**AI prompt — QA gate:**
```text
Audit all notification changes for RBAC/tenant leaks, IDOR, duplicate events,
transaction safety, retry behavior, performance and accessibility. Expand RSpec,
Vitest/Testing Library and Playwright tests. Run the actual project lint/typecheck,
test and build commands. Produce a coverage summary and a manual acceptance checklist.
Do not mark a phase complete when relevant tests are failing.
```

## 14. Deployment, rollout and rollback — Phase 12

> **Runbook produced:** 📋 See [PHASE_12_DEPLOYMENT_ROLLOUT_ROLLBACK.md](PHASE_12_DEPLOYMENT_ROLLOUT_ROLLBACK.md). No production deployment was performed as part of this change; the document is the approved order of operations, monitoring queries and non-destructive rollback.

1. Verify Render service type, runtime, queue worker capability and Neon DB configuration.
2. Add additive migrations; deploy backend with event creation disabled behind a feature flag.
3. Run migrations, inspect indexes and test unread endpoints with test accounts.
4. Deploy frontend bell behind flag; validate desktop/mobile navigation and logout.
5. Enable training notifications for a small test group; inspect duplicate and recipient counts.
6. Expand organisation/tournament event types gradually.
7. Enable email only after durable worker, Brevo quotas and retries are validated.
8. Add optional push only after PWA compatibility testing.
9. Monitor errors, query performance, queue backlog, user feedback and cost.
10. Rollback by disabling event flags and UI; keep additive schema in place until safe cleanup.

**AI prompt — Release:**
```text
Prepare a deployment checklist for the actual BVH Render/Neon/Cloudflare setup.
Verify feature flags, DB migration order, queue worker startup, secrets, Brevo
settings, health checks and smoke tests. Provide explicit rollback commands for
code/flags and explain why destructive schema rollback should be avoided. Do not
assume Render free tier provides a reliable always-on worker.
```

## 15. Suggested delivery milestones

| Milestone | Included phases | Definition of done |
|---|---|---|
| MVP A | 0–4 | Authenticated bell, persistent API, unread count, inbox, mark-read; verified against Wine Words UX |
| MVP B | 5 | Training + organisation notifications delivered to correct recipients |
| Expansion | 6–7 | Tournaments/assessments/analysis/comments + preferences |
| External channels | 8 | Reliable Brevo email and retry/outbox in production |
| Subscription features | 9 | Optional follow-based updates |
| PWA | 10 | Explicit opt-in push, browser compatibility validated |
| Release quality | 11–12 throughout | Security, test coverage, monitoring and rollback documented |

## 16. Recommended first coding sequence

1. Run Phase 0 audit and create exact Wine Words-to-BVH mapping.
2. Confirm actual BVH Account/auth/API conventions and whether notification tables already exist.
3. Implement persistence and API behind feature flag.
4. Port Wine Words bell UI, not its domain-specific event rules.
5. Ship training cancellation/rescheduling and membership approvals as first end-to-end events.
6. Add additional events only after recipient/privacy tests pass.
7. Enable email and push only when worker and browser requirements are satisfied.

## 17. Official documentation and references

- Rails Active Job / Solid Queue: https://guides.rubyonrails.org/active_job_basics.html
- Solid Queue repository: https://github.com/rails/solid_queue
- TanStack Query polling: https://tanstack.com/query/latest/docs/framework/react/guides/polling
- Ruby Web Push: https://github.com/pushpad/web-push
- MDN Push API: https://developer.mozilla.org/en-US/docs/Web/API/Push_API
- MDN Notifications API: https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API

**Final recommendation:** Implement the first release with PostgreSQL-backed in-app notifications, existing React UI conventions, and simple foreground polling. Keep a channel-agnostic dispatcher and dedupe strategy from day one. Use Solid Queue only after production worker feasibility is verified; otherwise, avoid introducing an unreliable asynchronous dependency. Add Brevo email and Web Push as independent later phases.
