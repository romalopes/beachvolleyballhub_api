# Phase 0 — Repository Reconnaissance & Architecture Review

**Goal:** Confirm every assumption in the parent plan against the actual codebase, document all deviations, and produce the conventions reference that all subsequent phases will follow.

**Prerequisites:** Access to the repo (already have).

---

## What Was Inspected

| Area | Files / Commands | Key Findings |
|------|------------------|--------------|
| **API test framework** | `Gemfile`, `test/test_helper.rb`, `test/models/` | Minitest + fixtures, SimpleCov, parallelize, `api_test_helper.rb`, `session_test_helper.rb`, `create_account!` helper. **No RSpec.** |
| **Frontend test framework** | `beachvolleyballhub/package.json` | Vitest + React Testing Library (`npm run test`, `npm run test:coverage`, `npm run lint`) |
| **Roles** | `db/seeds.rb`, `db/migrate/20260917000002_add_curator_role.rb` | Seeded: `guest, player, coach, admin`; migration adds `curator`. No Support/Finance roles. |
| **Role helpers** | `app/models/user.rb` | `has_role?`, `player?`, `coach?`, `curator?`, `admin?`, `content_manager?` |
| **Authorization** | `app/policies/`, `app/controllers/api/v1/analyses_controller.rb` | Pundit everywhere. One policy per resource. `policy_scope` for collections. |
| **Routes** | `config/routes.rb` | `resources :analyses` with member/collection actions; `namespace :admin { resources :users }`. No `/my/` or `/coach/` prefixes. |
| **Serialization** | `app/controllers/api/v1/analyses_controller.rb` | Inline private `serialize(record, detail:)` — no jbuilder/serializer classes. |
| **Notifications** | `app/models/notification.rb`, `app/services/notifications/publisher.rb`, `app/services/notifications/workflow_events.rb` | `event_key` idempotency, `Notification` belongs to `account`, polymorphic `notifiable`. |
| **Email** | `lib/mail_transport.rb`, `app/mailers/` | `MailTransport` resolves brevo/resend/smtp/file. 9 mailers. Solid Queue (`deliver_later`). |
| **Settings** | `app/models/app_setting.rb` | Key/value with typed accessors (`boolean`, `string`, `set!`), defaults. |
| **Video attachment pattern** | `app/models/analysis_video.rb` | `has_one_attached :file`, `source_type: external/upload`, content-type/size validation, position ordering. **No "attachable concern" exists.** |
| **Guest endpoints** | `app/controllers/api/v1/contact_messages_controller.rb` | `allow_unauthenticated_access`, honeypot, Turnstile, Rack::Attack throttle, minimal response. |
| **Rate limiting** | `config/initializers/rack_attack.rb` | Exists, used by contact form. |
| **Money columns** | `db/schema.rb` (subscriptions) | Integer `*_cents` with check constraint `>= 0`. |
| **Frontend routes** | `beachvolleyballhub/src/App.tsx` | `/analysis` = existing Analysis list. `/hire-analysis` = **placeholder "Coming Soon" page** (line 832). |
| **API client** | `beachvolleyballhub/src/api.ts` | Bearer token from localStorage, `postFormData` for uploads, `ApiValidationError`, test-access gate. |
| **Existing Analysis feature** | `app/models/analysis.rb`, `app/models/analysis_video.rb`, `app/models/analysis_participant.rb`, `app/controllers/api/v1/analyses_controller.rb` | **`Analysis` model exists** (Analysis-of-Players). Uses `AnalysisVideo` (external/upload) + `AnalysisParticipant`. Safe to add `AnalysisRequest`. |
| **DB conventions** | Recent migrations (`20261121*`) | Enum/status columns get check constraints in same migration. Unique indexes where validated. |
---

## Deviations from Parent Plan (Documented Here → Referenced in Later Phases)

| # | Parent Plan Assumption | Reality | Resolution (carried forward) |
|---|------------------------|---------|------------------------------|
| 1 | Frontend routes `/analysis/hire`, `/analysis/hire/submit`, `/my/analysis-requests` | `/hire-analysis` exists as placeholder; `/analysis` is Analysis-of-Players | **Reuse `/hire-analysis`** as landing; add `/hire-analysis/submit`, `/my/analysis-requests`, `/my/analysis-requests/:id`, `/coach/analysis-requests`, `/admin/analysis-requests` |
| 2 | Videos "reuse existing Video model and its attachable concern" | **No attachable concern exists.** Pattern is `AnalysisVideo` (`has_one_attached :file`, external/upload) | `AnalysisRequestVideo` follows **`AnalysisVideo` pattern** |
| 3 | "Test-driven" (framework unspecified) | API = Minitest; Frontend = Vitest | Phase docs specify `bin/rails test` and `npm run test` |
| 4 | API paths `GET /api/v1/my/analysis_requests`, `GET /api/v1/coach/analysis_requests`, `GET /api/v1/admin/analysis_requests` | Repo uses resourceful routes + `namespace :admin` | `resources :analysis_requests` + `collection { get :mine }` + `namespace :admin { resources :analysis_requests }` + coach as collection filter |
| 5 | "Crew" = Support/Finance roles | Only `guest, player, coach, admin, curator` exist | Crew recipients via **`AppSetting`** (configurable email lists) |
| 6 | Pricing config unspecified | `AppSetting` exists + `*_cents` pattern | `AnalysisPackage` prices in cents; crew settings in `AppSetting` |
| 7 | Guest submission pattern unspecified | `ContactMessagesController` is exact precedent | Mirror its layered abuse controls |
| 8 | Notifications — build new | `Publisher` + `WorkflowEvents` + `Notification` + preferences exist | **Extend existing system** with new event types |
| 9 | Email — build new | `MailTransport` + 9 mailers + Solid Queue | New mailers extend `ApplicationMailer`, `deliver_later` |
| 10 | Messaging — "reuse Wine Words conversation patterns" | BVB has no conversation system; closest: `analysis_comments`, `contact_messages` admin inbox | Build `AnalysisRequestMessage` fresh, BVB conventions |
| 11 | Guest claim — new flow | `claim_invitation`, `player_claim`, `email_verifications`, `EmailVerificationService` exist | Reuse token/verification patterns |
| 12 | Rate limiting — new | `rack_attack.rb` exists | Add throttles for new guest endpoints |
| 13 | Serialization — new | Inline `serialize` methods in controllers | Follow existing convention |
| 14 | Stripe integration | `stripe` gem + `billing_*` models exist (IDENTITY-116) | **Deferred per plan** — phase docs note future hook only |
| 15 | Naming: "Analysis Request" | `Analysis` model exists (Analysis-of-Players) | Plan correctly chose `AnalysisRequest` — confirmed safe |

---

## Verification Commands (run after this phase)

```bash
# API tests (should all pass — no new code yet)
cd /Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api
bin/rails test

# Frontend tests (should all pass)
cd /Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub
npm run test
npm run lint
```

**Result:** ✅ All existing tests pass. No new code introduced.

---

## Updated Parent Plan

- [x] Phase 0 status badge added to `## Phase 0` heading in `../beachvolleyballhub_hire_analysis_detailed_plan.md`
- [x] This deviation table referenced in the Implementation Status section at top of parent plan