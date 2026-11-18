# Phase 2 — Email delivery, background jobs and notifications

**Parent plan:** [beachvolleyballhub_contact_messages_implementation_plan.md](beachvolleyballhub_contact_messages_implementation_plan.md)
**Plan section:** §4.4, §4.5, §4.3 (reliability), §9
**Status:** Complete — **but delivery requires a deployed worker** (see §6).

## 1. Delivered files

| File | Purpose |
|---|---|
| `lib/contact_recipients.rb` | Parses `CONTACT_NOTIFICATION_EMAILS` defensively |
| `config/application.rb` | `require_relative "../lib/contact_recipients"` (mirrors `MailSender`) |
| `app/mailers/contact_message_mailer.rb` | `notification(contact_message, inbox_url:)` |
| `app/views/contact_message_mailer/notification.html.erb` | HTML body (escaped, `pre-wrap`) |
| `app/views/contact_message_mailer/notification.text.erb` | Plain-text alternative |
| `app/jobs/contact_message_delivery_job.rb` | Email + in-app notification, retry-safe |
| `app/services/notifications/workflow_events.rb` | New `contact_message_received` rule |
| `app/controllers/api/v1/contact_messages_controller.rb` | Enqueues delivery after the message is stored |
| `beachvolleyballhub_api/render.yaml` | Contact env vars on the **web service and the existing `bvb-api-worker`** |
| `test/lib/contact_recipients_test.rb`, `test/mailers/contact_message_mailer_test.rb`, `test/jobs/contact_message_delivery_job_test.rb` | Recipient parsing, mail content, job behaviour |
| `.env.example` | `CONTACT_NOTIFICATION_EMAILS`, `TURNSTILE_*`, rate-limit overrides |

## 2. Recipient configuration

`CONTACT_NOTIFICATION_EMAILS` is a comma-separated **recipient** list and is
deliberately separate from `MAIL_REPLY_TO`:

```env
CONTACT_NOTIFICATION_EMAILS=support@beachvolleyballhub.com,admin@beachvolleyballhub.com
MAIL_REPLY_TO=support@beachvolleyballhub.com
```

`ContactRecipients.list` trims, de-duplicates case-insensitively (keeping the
first spelling), drops invalid entries (available separately for an operator log
via `.invalid`) and validates with an **anchored** e-mail pattern so a value
containing CR/LF can never become a header. `MAIL_REPLY_TO` was **not** touched:
`ApplicationMailer` still uses it as the application-wide Reply-To.

## 3. The email

- **To**: every configured recipient (one message — an internal staff
  notification, so a single atomic delivery is safer to retry than one send per
  address).
- **From**: the application sender inherited from `ApplicationMailer`
  (`MailSender.from`). The visitor is **never** the envelope sender.
- **Reply-To**: the visitor's validated address, only when present — pressing
  Reply in a mail client addresses the enquirer.
- **Subject**: `New contact message: <subject>`.
- **Body (HTML + text)**: sender name/e-mail, human-readable category, subject,
  full message (escaped, `white-space: pre-wrap`), submission time with timezone,
  and an absolute link to `FRONTEND_URL/settings/contact-messages/:id`.
- A mailer test proves `<script>`/`<img onerror>` in the payload is escaped and
  never becomes live markup.

## 4. In-app notifications

`Notifications::WorkflowEvents.contact_message_received(message, recipients:)`
publishes through the existing `Notifications::Publisher` with:

| Field | Value |
|---|---|
| `event_type` | `contact.message.received` |
| `event_key` | `contact_message:<id>:received` (per-recipient dedupe) |
| `title` | `New contact message` |
| `message` | sender, category and subject (no private detail) |
| `target_path` | `/settings/contact-messages/:id` |
| `target_label` | the subject |
| `notifiable` | the `ContactMessage` |

Recipients are the **Accounts of users holding the global `admin` or `curator`
role** (`UserRole` → `Role`). Coaches, players, ordinary accounts and
organisation members are not notified; organisation roles live in a different
table, so they can never leak in. A staff user without an Account receives
nothing (there is nowhere to deliver it), which the job documents.

## 5. Reliability model

1. The row is **committed first** (controller `save` → then `perform_later`).
2. Only the **id** crosses the queue boundary.
3. `emailed_at` and `notified_at` are **idempotency guards**: a retry (or a
   duplicate enqueue) skips work that already happened, and the notification
   `event_key` dedupes per recipient as a second line of defence.
4. Mail is delivered **outside** any database transaction; the job never opens
   one.
5. A failure is logged without message content and **re-raised**, so
   `retry_on StandardError, wait: :polynomially_longer, attempts: 3` retries it
   and monitoring sees it.
6. A queue outage does not turn a stored message into a visitor-facing error: the
   controller rescues the enqueue error and logs an operational event.
7. An unconfigured or entirely invalid recipient list is logged and skips the
   email — the message stays stored and visible in the inbox.

Job tests prove: exactly one email per run, correct Reply-To/From, admin+curator
targeting only, no duplicate email or notification on a second run, the message
surviving a delivery failure, and `perform` re-raising so the retry policy (which
enqueues a retry through `perform_now`) works.

## 6. Deployment requirement (operator step)

The API's active blueprint (`beachvolleyballhub_api/render.yaml`) already declares
a continuously running Solid Queue worker:

```yaml
- type: worker
  name: bvb-api-worker
  runtime: docker
  dockerCommand: ./bin/jobs
```

This feature therefore needs **configuration, not a new service**:

1. Add `CONTACT_NOTIFICATION_EMAILS` to **both** `bvb-api` and `bvb-api-worker`
   (the blueprint now lists it on each, as `sync: false`).
2. Confirm the worker has the same mail settings as the web service
   (`MAIL_TRANSPORT`, `MAIL_FROM`, `MAIL_REPLY_TO`, `BREVO_API_KEY`, …). The
   blueprint already mirrors them; a worker missing them would deliver with a
   different sender or fail outright.
3. Verify a submission produces a processed `ContactMessageDeliveryJob` in the
   worker logs (`bvb-api-worker` → Logs).

Until the recipient variable is set on the worker, submissions are still
persisted and visible in the inbox — only the fan-out is skipped and logged.

## 7. Tests

```bash
bin/rails test test/lib/contact_recipients_test.rb \
  test/mailers/contact_message_mailer_test.rb \
  test/jobs/contact_message_delivery_job_test.rb
```

## 8. Exit criteria

| Criterion | Result |
|---|---|
| Each configured recipient receives an email | ✅ one message to all of them |
| Sender e-mail is Reply-To, not From | ✅ |
| User input escaped in HTML, present in plain text | ✅ |
| Mail failure does not delete the persisted message | ✅ |
| All eligible platform Admins/Curators receive one notification | ✅ |
| Organisation-level roles, coaches and ordinary accounts excluded | ✅ |
| Retried jobs do not duplicate notifications or email | ✅ |
| No recipient address or secret exposed publicly | ✅ |
| Production worker processes the new jobs | ✅ `bvb-api-worker` exists — add `CONTACT_NOTIFICATION_EMAILS` to it (§6) |
