# Phase 2 — Public Pricing/Packages & Submission API Enhancements

**Goal:** Create configurable `AnalysisPackage` model, public pricing endpoint, and enhance submission API with package selection + video upload handling.

**Prerequisites:** Phase 1 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Migration** | `db/migrate/20261122000003_create_analysis_packages.rb` |
| **Model** | `app/models/analysis_package.rb` |
| **Controller** | `app/controllers/api/v1/analysis_packages_controller.rb` (public) |
| **Controller** | Update `AnalysisRequestsController` for package selection + video uploads |
| **Routes** | `config/routes.rb` (add `resources :analysis_packages, only: :index`) |
| **Tests** | `test/models/analysis_package_test.rb`, `test/controllers/api/v1/analysis_packages_controller_test.rb` |
| **Fixtures** | `test/fixtures/analysis_packages.yml` |

---

## Database Schema

```ruby
# db/migrate/20261122000003_create_analysis_packages.rb
class CreateAnalysisPackages < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_packages do |t|
      t.string :key, null: false, index: { unique: true } # e.g., "single_match", "season_review"
      t.string :name, null: false
      t.text :description
      t.integer :price_cents, default: 0, null: false
      t.integer :max_videos, default: 1, null: false
      t.integer :max_duration_minutes, default: 30, null: false
      t.boolean :includes_annotated_video, default: false, null: false
      t.boolean :includes_written_report, default: true, null: false
      t.boolean :includes_consultation, default: false, null: false
      t.integer :turnaround_days, default: 7, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE analysis_packages
        ADD CONSTRAINT analysis_packages_price_cents_check
        CHECK (price_cents >= 0);
    SQL
  end
end
```

---

## Model: `AnalysisPackage`

```ruby
# app/models/analysis_package.rb
class AnalysisPackage < ApplicationRecord
  has_many :analysis_requests, foreign_key: :package_key, primary_key: :key

  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_videos, numericality: { only_integer: true, greater_than: 0 }
  validates :max_duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :turnaround_days, numericality: { only_integer: true, greater_than: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true).order(:position, :id) }
  scope :ordered, -> { order(:position, :id) }

  def price_aud
    return "Complimentary" if price_cents == 0
    "$#{'%.2f' % (price_cents / 100.0)} AUD"
  end
end
```

---

## Public Packages Controller

```ruby
# app/controllers/api/v1/analysis_packages_controller.rb
module Api
  module V1
    class AnalysisPackagesController < ApplicationController
      allow_unauthenticated_access # public pricing page

      # GET /api/v1/analysis_packages
      def index
        packages = AnalysisPackage.active
        render json: { data: packages.map { |p| serialize(p) } }
      end

      private

      def serialize(p)
        {
          key: p.key,
          name: p.name,
          description: p.description,
          price_cents: p.price_cents,
          price_aud: p.price_aud,
          max_videos: p.max_videos,
          max_duration_minutes: p.max_duration_minutes,
          includes_annotated_video: p.includes_annotated_video,
          includes_written_report: p.includes_written_report,
          includes_consultation: p.includes_consultation,
          turnaround_days: p.turnaround_days
        }
      end
    end
  end
end
```

---

## Routes

```ruby
# config/routes.rb
resources :analysis_packages, only: [:index] # public
```

---

## Submission API Enhancements

- `AnalysisRequest.create` validates `package_key` exists and is active
- Video upload handling via `postFormData` (multipart) — mirror `uploadOrganisationLogo` pattern
- Guest submissions: rate limit via Rack::Attack (throttle by IP + email)
- Honeypot + Turnstile validation (mirror `ContactMessagesController`)

---

## Test Plan

- Package CRUD (admin only for write, public read)
- Package validation: price_cents ≥ 0, unique key
- Public index returns only active packages ordered by position
- Submission with valid package_key → price_cents copied from package
- Submission with invalid package_key → 422
- Video upload: file attached, content-type video/*, size ≤ limit
- Rate limiting: >5 submissions/hour/IP → 429

---

## Acceptance Criteria

- [ ] Migration runs cleanly
- [ ] `bin/rails test` passes for package model + controller
- [ ] GET `/api/v1/analysis_packages` returns public pricing
- [ ] POST `/api/v1/analysis_requests` with package_key works
- [ ] Video upload via multipart works (ActiveStorage)
- [ ] Rate limiting + honeypot + Turnstile enforced on guest submit

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Admin UI for packages | Phase 3 will add admin list/detail | Keep phases focused |
| Stripe price_id | Not used (manual invoicing per plan) | Deferred to future |

---

## Addendum: Submitter identity gate (implemented post-plan)

The submission flow now resolves *who* the analysis belongs to before anything
is sent, mirroring the Wine Words trade-submission pattern:

**API — `GET /api/v1/email_check?email=…`** (public, `EmailChecksController`)
- Rate limited (20/min via `rate_limit`); response is intentionally minimal:
  `{ email_address, registered }` — an account-existence oracle and nothing else.

**Frontend — `HireAnalysisPage` review step**
- Signed-in submitters skip the gate entirely; their submission never carries
  guest fields.
- Guests: on "Confirm & Submit" the email is probed.
  - Registered email → inline **login card** ("Welcome back"); logging in
    submits the request under the account. Pending email verification (202)
    keeps the guest escape hatch available.
  - Unknown email → inline **signup card** ("Create your Beach Volleyball Hub
    account") with first/last name, password + confirmation, a "Why create an
    account?" benefits panel (save time, manage requests, track progress, get
    notified, access the analysis, message the team), **Continue as guest** and
    **Create account & submit**. Registration pending verification keeps the
    guest path open.
  - Probe failure (network/API down) → falls through to a plain guest
    submission; the check is advisory, never a blocker.
- Turnstile widgets are embedded in both cards when the site key is configured.

**Backend — submitter player identity**
- `analysis_requests.player_profile_id` (nullable FK, migration
  `20261123090000`).
- `AnalysisRequests::SubmitterProfile.for_user(user)` reuses the account's
  active player profile or creates one on the fly (display name falls back to
  the user label when the account has no contact details; creation failure
  never blocks the request).
- `AnalysisRequests::AnalysisStarter` adds the submitter's profile as an
  `AnalysisParticipant` of the produced Analysis, so the finished work is
  domain-owned by the player.

**Tests** — `email_checks_controller_test`, submitter-profile service tests,
authenticated-create profile linking/reuse in `analysis_requests_controller_test`,
participant assertions in `analysis_starter_test`; SPA flows in
`HireAnalysisPage.test.tsx` (login card, signup card + submit, guest escape,
probe-failure fallback).