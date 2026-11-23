# Phase 6 — Notifications Bell & Event Coverage

**Goal:** Wire all AnalysisRequest workflow events into the existing Notification bell system (IDENTITY-249).

**Prerequisites:** Phase 5 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Notifications** | `app/services/notifications/workflow_events.rb` (add AnalysisRequest events) |
| **Model** | `app/models/notification_preference.rb` (add new event types) |
| **Frontend** | `NotificationBell` component already exists — no changes needed |
| **Tests** | Verify each event creates Notification with correct `event_key` |

---

## Events to Add (in `WorkflowEvents`)

```ruby
module Notifications
  class WorkflowEvents
    # ... existing events ...

    def self.analysis_request_submitted(request)
      create_for_crew(
        event_type: "analysis_request.submitted",
        event_key: "analysis_request_submitted_#{request.id}",
        title: "New Analysis Request",
        message: "#{request.submitter_name} submitted \"#{request.title}\"",
        notifiable: request,
        actor: request.account&.user
      )
    end

    def self.analysis_request_accepted(request)
      create_for_recipient(request.submitter_account,
        event_type: "analysis_request.accepted",
        event_key: "analysis_request_accepted_#{request.id}",
        title: "Request Accepted",
        message: "Your analysis request \"#{request.title}\" was accepted.",
        notifiable: request
      )
      create_for_crew(...)
    end

    def self.analysis_request_rejected(request)
      create_for_recipient(request.submitter_account, ...)
    end

    def self.analysis_request_quoted(request)
      create_for_recipient(request.submitter_account, ...)
    end

    def self.analysis_request_coach_assigned(request)
      create_for_recipient(request.assigned_coach_profile.account, ...)
      create_for_crew(...)
    end

    def self.analysis_request_message_created(message)
      recipients = message.from_submitter? ? message.request.crew_accounts : [message.request.submitter_account]
      recipients.each { |acc| create_for_recipient(acc, ...) }
    end

    def self.analysis_request_invoice_sent(request)
      create_for_recipient(request.submitter_account, ...)
    end

    def self.analysis_request_payment_received(request)
      create_for_recipient(request.submitter_account, ...)
      create_for_crew(...)
    end

    def self.analysis_request_overdue(request)
      create_for_recipient(request.submitter_account, ...)
      create_for_crew(...)
    end

    def self.analysis_request_work_started(request)
      create_for_recipient(request.submitter_account, ...)
    end

    def self.analysis_request_completed(request)
      create_for_recipient(request.submitter_account, ...)
    end

    def self.analysis_request_deliverable_uploaded(request)
      create_for_recipient(request.submitter_account, ...)
    end

    private

    def self.create_for_crew(attrs)
      crew_accounts = AppSetting.crew_notification_accounts # array of account_ids
      crew_accounts.each { |acc| create_for_recipient(acc, attrs) }
    end

    def self.create_for_recipient(account, attrs)
      return unless account
      Notification.create_or_find_by!(
        account: account,
        event_key: attrs[:event_key]
      ) do |n|
        n.assign_attributes(attrs.merge(actor_account: attrs[:actor]))
      end
    end
  end
end
```

---

## Notification Preferences

Add to `NotificationPreference` (or `AppSetting` for crew):
- `analysis_request_submitted` (crew)
- `analysis_request_accepted` (submitter)
- `analysis_request_rejected` (submitter)
- `analysis_request_quoted` (submitter)
- `analysis_request_coach_assigned` (coach + crew)
- `analysis_request_message` (submitter + crew)
- `analysis_request_invoice_sent` (submitter)
- `analysis_request_payment_received` (submitter + crew)
- `analysis_request_overdue` (submitter + crew)
- `analysis_request_work_started` (submitter)
- `analysis_request_completed` (submitter)
- `analysis_request_deliverable` (submitter)

---

## Acceptance Criteria

- [ ] Every workflow transition creates Notification via `WorkflowEvents`
- [ ] `event_key` ensures idempotency (no duplicates on retry)
- [ ] Crew recipients configurable via `AppSetting`
- [ ] Notification preferences respected (opt-out per event type)
- [ ] Bell updates in real-time (existing Turbo/ActionCable works)
- [ ] `bin/rails test` passes

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Crew recipient config | `AppSetting.crew_notification_accounts` | No Support/Finance roles; flexible list |
| Real-time bell | Existing Turbo/ActionCable reused | Already implemented in IDENTITY-249 |