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