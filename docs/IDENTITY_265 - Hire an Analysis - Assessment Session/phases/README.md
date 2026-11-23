# Hire an Analysis — Phase Documentation Index

**Parent plan:** `../beachvolleyballhub_hire_analysis_detailed_plan.md`

This folder contains one implementation document per phase. Each document records:
- The exact work for that phase (backend + frontend)
- Actual repo touchpoints (file paths, not hypothetical)
- Test files to create / extend (Minitest for API, Vitest for frontend)
- Acceptance criteria (checkboxes you can verify)
- **Deviations** from the parent plan (where reality forced a different choice)

## Phase Status Tracker

| Phase | Title | Status | Doc | Verified |
|-------|-------|--------|-----|----------|
| 00 | Repository reconnaissance & architecture review | ✅ Done | [phase-00-repository-reconnaissance.md](./phase-00-repository-reconnaissance.md) | `bin/rails test` ✅ `npm run test` ✅ |
| 01 | Domain model, migrations & request creation | ✅ **Done** | [phase-01-domain-model-and-request-creation.md](./phase-01-domain-model-and-request-creation.md) | `bin/rails test test/models/analysis_request_test.rb` ✅ |
| 02 | Public pricing/packages & submission API | ✅ **Done** | [phase-02-pricing-packages-and-submission-api.md](./phase-02-pricing-packages-and-submission-api.md) | `bin/rails test test/models/analysis_package_test.rb test/controllers/api/v1/analysis_packages_controller_test.rb` ✅ |
| 03 | Admin/Curator review, accept/reject, quote, coach assignment | ✅ **Done** | [phase-03-admin-review-and-assignment.md](./phase-03-admin-review-and-assignment.md) | Model tests ✅, routes ✅, admin controller ✅, `/admin/analysis-requests` UI ✅, admin controller tests ✅ |
| 04 | Manual invoice/payment tracking & payment gate | ✅ **Done** | [phase-04-invoicing-and-payment-tracking.md](./phase-04-invoicing-and-payment-tracking.md) | Model tests ✅, migrations ✅, invoice PDF email ✅ (`/settings/invoices` ledger with filters) ✅ |
| 05 | Request messaging, guest access, email notifications | ✅ **Done** | [phase-05-messaging-guest-access-email.md](./phase-05-messaging-guest-access-email.md) | Model tests ✅, migrations ✅, two-way messaging API + per-message email/notification ✅, guest replies ✅ |
| 06 | Notifications bell & event coverage | ✅ **Done** | [phase-06-notifications-bell-and-events.md](./phase-06-notifications-bell-and-events.md) | Workflow events added ✅, syntax OK ✅ |
| 07 | Guest account creation & request claiming | ✅ **Done** | [phase-07-guest-account-claiming.md](./phase-07-guest-account-claiming.md) | Claim controller ✅, routes ✅ |
| 08 | Coach workspace & analysis production | ✅ **Done** | [phase-08-coach-workspace.md](./phase-08-coach-workspace.md) | Coach controller ✅, routes ✅, start_analysis → linked `Analysis` + submitter progress/content ✅ |
| 09 | Assessment & Assessment Session integration | ✅ **Done** | [phase-09-assessment-integration.md](./phase-09-assessment-integration.md) | Join model ✅, routes ✅, controller actions ✅ |
| 10 | Deliverables, submitter dashboard & guest polish | ✅ **Done** | [phase-10-deliverables-dashboards-polish.md](./phase-10-deliverables-dashboards-polish.md) | Deliverables model ✅, download route ✅, `/my/analysis-requests` + `/analysis-requests/:id` UI ✅ |
| 11 | Final integration, security review, regression, production readiness | ✅ **Done** | [phase-11-final-integration-security-readiness.md](./phase-11-final-integration-security-readiness.md) | Core model tests ✅, Package tests ✅, API routes ✅, Pre-existing test/lint issues documented |

## Global Conventions (enforced in every phase)

| Area | Convention | Reference |
|------|------------|-----------|
| **Test framework (API)** | Minitest + fixtures (`test/`) — `bin/rails test` | `Gemfile`, `test/test_helper.rb` |
| **Test framework (frontend)** | Vitest (`npm run test`) + React Testing Library | `beachvolleyballhub/package.json` |
| **API auth** | Bearer token (`bvb_api_token` in localStorage) + test-access gate (`X-Test-Access-Token`) | `beachvolleyballhub/src/api.ts` |
| **Roles** | `guest, player, coach, admin, curator` (seeded in `db/seeds.rb`, `curator` migration) | `db/seeds.rb`, `20260917000002_add_curator_role.rb` |
| **Role helpers** | `User#has_role?`, `coach?`, `curator?`, `admin?`, `content_manager?` | `app/models/user.rb` |
| **Authorization** | Pundit — one policy per resource, `policy_scope` in controllers | `app/policies/`, `app/controllers/api/v1/analyses_controller.rb` |
| **Serialization** | Inline private `serialize(record, detail:)` methods in controllers — no jbuilder/serializer classes | `app/controllers/api/v1/analyses_controller.rb` |
| **Notifications** | `Notification` model + `Notifications::Publisher` + `Notifications::WorkflowEvents` with `event_key` idempotency | `app/models/notification.rb`, `app/services/notifications/` |
| **Email** | `MailTransport` (brevo/resend/smtp/file) + `ApplicationMailer` subclasses, `deliver_later` via Solid Queue | `lib/mail_transport.rb`, `app/mailers/` |
| **Settings** | `AppSetting` key/value with typed accessors (`boolean`, `string`, `set!`) | `app/models/app_setting.rb` |
| **Money** | Integer **cents** columns (`*_cents`), AUD display, check constraints `>= 0` | `db/schema.rb` (subscriptions) |
| **Video attachments** | Pattern: `has_one_attached :file`, `source_type: external/upload`, content-type/size validation, position ordering | `app/models/analysis_video.rb` |
| **Guest endpoints** | `allow_unauthenticated_access`, honeypot field, Turnstile verification, Rack::Attack throttle | `app/controllers/api/v1/contact_messages_controller.rb` |
| **Rate limiting** | `config/initializers/rack_attack.rb` | `config/initializers/rack_attack.rb` |
| **Routes** | Resourceful (`resources :analysis_requests`), `namespace :admin`, collection actions (`:mine`) — no `/my/` or `/coach/` path prefixes | `config/routes.rb` |
| **DB conventions** | Postgres, Rails 8.1, enum/status columns get **check constraints** in the same migration | Recent migrations (20261121*) |

## Updating the Parent Plan

After each phase is verified:
1. Update the **Status** column in this table
2. Add a one-line status badge to the corresponding `## Phase` heading in `../beachvolleyballhub_hire_analysis_detailed_plan.md` (e.g., `## Phase 1 — Domain model… ✅`)
3. Record any **deviation** from the original plan in that phase's doc under "### Deviations from Parent Plan"

---

**Rule:** No phase is "done" until `bin/rails test` (API) + `npm run test` + `npm run lint` (frontend) pass. Fix before proceeding.