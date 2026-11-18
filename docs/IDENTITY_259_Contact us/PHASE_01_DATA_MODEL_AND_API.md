# Phase 1 — Data model, policies and API

**Parent plan:** [beachvolleyballhub_contact_messages_implementation_plan.md](beachvolleyballhub_contact_messages_implementation_plan.md)
**Plan section:** §4.1–§4.3, §5.2, §8
**Status:** Complete.

## 1. Delivered files

| File | Purpose |
|---|---|
| `db/migrate/20261117000001_create_contact_messages.rb` | Table, indexes, status CHECK constraint |
| `app/models/contact_message.rb` | Allowlists, normalisation, validation, scopes, status transitions |
| `app/policies/contact_message_policy.rb` | Platform staff only (`admin`/`curator`) + scope |
| `app/controllers/api/v1/contact_messages_controller.rb` | Public `create` + `options` |
| `app/controllers/api/v1/admin/contact_messages_controller.rb` | Inbox `index`/`show`/`update`/`unread_count` |
| `config/routes.rb` | The six routes below |
| `test/fixtures/contact_messages.yml` | Three inbox fixtures (unread, read, archived) |
| `test/models/contact_message_test.rb` | Model rules, transitions, scopes |
| `test/policies/contact_message_policy_test.rb` | Authorization matrix + scope |
| `test/controllers/api/v1/contact_messages_controller_test.rb` | Public endpoint |
| `test/controllers/api/v1/admin/contact_messages_controller_test.rb` | Inbox endpoints |

## 2. Schema

`contact_messages`

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | Project default |
| `name` | string, NOT NULL | Max 120 |
| `email` | string, NOT NULL | Max 254, anchored `URI::MailTo::EMAIL_REGEXP` |
| `contact_type` | string, NOT NULL | Validated against `ContactMessage::CONTACT_TYPES` |
| `subject` | string, NOT NULL | Max 180 |
| `message` | text, NOT NULL | Max 10 000; plain text |
| `status` | string, NOT NULL, default `unread` | DB CHECK `unread|read|archived` |
| `read_at`, `archived_at` | datetime | Kept consistent with `status` |
| `emailed_at`, `notified_at` | datetime | Phase 2 delivery markers (idempotency) |
| `created_at`, `updated_at` | datetime | |

Indexes: `(status, created_at)`, `created_at`, `contact_type`,
`(status, archived_at)`.

**There is no `user_id`.** A public message is never linked to an Account,
PlayerProfile, CoachProfile, Organisation, TrainingSession or Tournament. A model
test asserts the columns stay absent so a later change cannot quietly start
trusting form input for identity.

## 3. Model behaviour

- **Allowlist**: `general, account_access, coaching, organisation,
  training_tournament, location, technical_support, partnership, feedback, other`
  with human labels in `CONTACT_TYPE_LABELS` (also served by the options endpoint).
- **Normalisation**: name/subject/message/e-mail trimmed; `contact_type`
  downcased; e-mail downcased (matching `User#email_address`).
- **Validation**: required fields, length caps, e-mail format, allowlist
  membership, status membership, and **no control characters** in name/subject/
  e-mail (CR/LF is header-injection material).
- **Transitions**: `mark_read!`, `mark_unread!`, `archive!`, `apply_status!`.
  All idempotent; read/unread *unarchive* (plan §4.2 recommendation), and
  `read_at` is cleared when returning to unread.
- **Scopes**: `by_recency`, `unread`, `read_messages`, `archived`,
  `not_archived`, `matching(term)` (parameterised `ILIKE` with
  `sanitize_sql_like`, so `%`/`_` stay literal).

## 4. API contract (as implemented)

| Method | Path | Access | Notes |
|---|---|---|---|
| `POST` | `/api/v1/contact_messages` | Anonymous | 201 `{ message: "..." }`; 422 `{ errors: [...] }`; 503 when Turnstile cannot verify |
| `GET` | `/api/v1/contact_messages/options` | Anonymous | `{ contact_types: [{ value, label }] }` |
| `GET` | `/api/v1/admin/contact_messages` | admin/curator | `data`, `meta`, `counts` |
| `GET` | `/api/v1/admin/contact_messages/unread_count` | admin/curator | `{ unread_count }`, `Cache-Control: private, no-store` |
| `GET` | `/api/v1/admin/contact_messages/:id` | admin/curator | `{ data: { ...message } }` |
| `PATCH` | `/api/v1/admin/contact_messages/:id` | admin/curator | Only `status`; idempotent |

Query parameters on the list: `status` (`all|unread|read|archived`),
`contact_type`, `search` (name/e-mail/subject), `page`, `per_page` (clamped to
100 by the `Pagination` concern), `sort` (`created_at|status`) and `direction`
(`asc|desc`). Every value is allow-listed; an unknown sort column falls back to
`created_at`, an unsupported status filter is ignored, and a pagination test
proves `per_page` cannot exceed 100.

The public response is deliberately minimal — a test asserts the body has exactly
one key (`message`) and contains no status, recipient or internal data.

## 5. Authorization

`ContactMessagePolicy` grants `index?`/`show?`/`update?` to
`admin? || curator?` (the **effective** user, so impersonation acts as the
impersonated user). `Scope#resolve` returns every row for staff and `none`
otherwise.

Because the inbox is not an admin-area surface, the controller authorises through
the policy rather than `authorize_admin!` — a Curator can answer support mail
without being granted the admin console.

Denials follow the app-wide contract: **401** anonymous, **403** authenticated for
list/update, **404** for read-by-id (so ids cannot be probed).

## 6. Tests

```bash
bin/rails test test/models/contact_message_test.rb \
  test/policies/contact_message_policy_test.rb \
  test/controllers/api/v1/contact_messages_controller_test.rb \
  test/controllers/api/v1/admin/contact_messages_controller_test.rb
```

Covered: valid/invalid persistence, allowlist rejection, length caps,
normalisation, CRLF rejection, every status transition (including
archive→read unarchiving), idempotency, search/filter/pagination/sort safety,
the full authorization matrix (anonymous, player, coach, curator, admin),
"public response leaks nothing", "public clients cannot set management fields",
and "only the status is writable".

## 7. Exit criteria

| Criterion | Result |
|---|---|
| Anonymous visitors can submit valid messages | ✅ |
| Invalid categories/fields rejected server-side | ✅ |
| Public users cannot list or read messages | ✅ (no public route exists) |
| Coaches and organisation-only roles cannot access the inbox | ✅ |
| Platform Admins/Curators can list and view messages | ✅ |
| Status updates authorized and idempotent | ✅ |
| Filtering/pagination bounded and safe | ✅ |
| Public response exposes no internal data | ✅ |
| Tests cover role boundaries | ✅ |
