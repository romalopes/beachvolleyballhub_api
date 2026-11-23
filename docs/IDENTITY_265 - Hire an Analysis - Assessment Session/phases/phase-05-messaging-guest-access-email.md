# Phase 5 — Request Messaging, Guest Access & Email Notifications

**Goal:** Threaded messaging per request (submitter ↔ BVB team), secure guest token access, email notifications for all key events.

**Prerequisites:** Phase 4 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Model** | `app/models/analysis_request_message.rb` |
| **Model** | `app/models/analysis_request_internal_note.rb` (staff-only) |
| **Controller** | `app/controllers/api/v1/analysis_request_messages_controller.rb` |
| **Controller** | Guest access endpoint (already in Phase 1) |
| **Mailer** | `app/mailers/analysis_requests_mailer.rb` (message notifications) |
| **Notifications** | `Notifications::WorkflowEvents` message events |
| **Routes** | Nested `resources :messages` on `analysis_requests` |
---

## Models

```ruby
# app/models/analysis_request_message.rb
class AnalysisRequestMessage < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_messages
  belongs_to :account, optional: true # nil for guest submitter
  belongs_to :user, optional: true # staff user

  validates :body, presence: true
  validates :from_submitter, inclusion: { in: [true, false] }
  validates :internal, inclusion: { in: [true, false] }

  scope :visible_to_submitter, -> { where(internal: false).order(:created_at) }
  scope :internal_notes, -> { where(internal: true).order(:created_at) }

  after_create :notify_recipients

  private

  def notify_recipients
    Notifications::WorkflowEvents.analysis_request_message_created(self)
  end
end

# app/models/analysis_request_internal_note.rb
class AnalysisRequestInternalNote < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_internal_notes
  belongs_to :account
  validates :body, presence: true
end
```

Migration: `create_analysis_request_messages` (analysis_request_id, account_id, user_id, body, from_submitter, internal) + `create_analysis_request_internal_notes` (analysis_request_id, account_id, body).
| **Tests** | Message CRUD, guest access, email delivery |

---

## Delivered: two-way conversation (IDENTITY-265 follow-up)

| Piece | File | Notes |
|-------|------|-------|
| API | `app/controllers/api/v1/analysis_request_messages_controller.rb` | `GET/POST /api/v1/analysis_requests/:id/messages` (owner, assigned coach, staff). Internal messages are filtered for non-staff and can only be created by staff. Blank/5000+ char bodies rejected. |
| Guest replies | `POST /api/v1/analysis_requests/guest_access/:token/messages` | Token is the credential; body always stored as `from_submitter`, never internal. Throttled to 10/hour/IP in `rack_attack.rb`. |
| Email | `AnalysisRequestsMailer#new_message` + text/HTML views | One email per message: submitter → crew (Reply-To submitter, staff link), team → submitter (Reply-To author, guest secure link / “my requests” link). Body escaped (`simple_format`). |
| Job | `AnalysisRequestMessageEmailJob` + `analysis_request_messages.emailed_at` | Off-request delivery, warn-and-skip when the other side has no address, retry-safe via `emailed_at`. |
| Notifications | `Notifications::WorkflowEvents.analysis_request_message_created` | Submitter messages notify crew **and** the assigned coach; team messages notify the submitter account. Internal messages never notify or email. |
| UI | `AnalysisRequestDetailPage` (Reply composer) and `GuestAnalysisRequestPage` (Send a message) | Both post, refresh/append, and surface errors; success notice explains that the other side was emailed and notified. |
| Tests | `api/v1/analysis_request_messages_controller_test.rb`, `analysis_request_message_email_job_test.rb`, mailer cases, 2 Vitest page tests | Cover permissions, internal exclusion, notifications, guest path, idempotent retries and both composers. |

**Known limit:** guest submitters have no account, so they receive the email but cannot receive an in-app notification (there is nothing to attach it to).