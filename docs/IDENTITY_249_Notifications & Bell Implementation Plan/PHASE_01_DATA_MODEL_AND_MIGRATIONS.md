# Phase 1 — Data model and migrations

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §4
**Status:** Complete.

## 1. Delivered

Migration: `db/migrate/20261101000001_create_notifications.rb`

### `notifications`

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | Project default |
| `account_id` | bigint, NOT NULL | Recipient. FK → `accounts`, `ON DELETE CASCADE` |
| `actor_account_id` | bigint | Who caused it. FK → `accounts`, `ON DELETE NULLIFY`, optional |
| `notifiable_type` / `notifiable_id` | polymorphic | Target record (TrainingSession, Organisation, Group, …), optional |
| `event_type` | string, NOT NULL | Stable machine-readable kind, e.g. `training.cancelled` |
| `event_key` | string, NOT NULL | Idempotency key, unique per recipient |
| `title` | string, NOT NULL | Short heading |
| `message` | text, NOT NULL | Body |
| `target_path` | string | **Internal SPA route only** (never an absolute URL → no open redirect) |
| `target_label` | string | Human label for the link |
| `metadata` | jsonb, NOT NULL, default `{}` | Extra payload (e.g. new start/end times) |
| `read_at` | datetime | NULL = unread |
| `emailed_at`, `email_failed_at`, `email_error` | datetime / text | Reserved for the Phase 8 email outbox; unused in v1 |
| `created_at`, `updated_at` | datetime | |

Indexes:
- `UNIQUE (account_id, event_key)` — the dedupe guard.
- `(account_id, read_at, created_at)` named `index_notifications_inbox` — the inbox query
  (unread count + newest-first list).
- `(event_type, created_at)` — filtering/metrics.

### `notification_preferences`

| Column | Type | Notes |
|---|---|---|
| `account_id` | bigint, NOT NULL | FK → `accounts`, `ON DELETE CASCADE`, **UNIQUE** |
| `in_app_enabled` | boolean, NOT NULL, default `true` | |
| `email_enabled` | boolean, NOT NULL, default `false` | |
| `email_cadence` | string, NOT NULL, default `"immediate"` | DB CHECK: `immediate|daily|weekly|none` |
| `muted_event_types` | jsonb, NOT NULL, default `[]` | |

A missing preference row means "defaults", so **no backfill is required** for existing accounts.

## 2. Models

- `app/models/notification.rb` — `belongs_to :account`, `belongs_to :actor_account` (optional),
  `belongs_to :notifiable` (polymorphic, optional); presence validations; `by_recency` and
  `unread` scopes; `read?` and idempotent `mark_read!`.
- `app/models/notification_preference.rb` — cadence inclusion validation, array validation for
  mutes, and `event_enabled?(event_type)` (used by the publisher).
- `app/models/account.rb` — added `has_many :notifications, dependent: :destroy` and
  `has_one :notification_preference, dependent: :destroy`.

### Important design decision: no uniqueness *validation*

`validates :event_key, uniqueness:` was deliberately **not** added. `Notifications::Publisher`
uses `create_or_find_by!`, which resolves a replay by catching the database's unique-violation;
a model validation would raise `RecordInvalid` before the insert and defeat that path. The
unique **index** is therefore the real guard (and the only one that survives a race). This is
asserted directly in the tests.

## 3. Tests

`test/models/notification_test.rb`, `test/models/notification_preference_test.rb`:

- required fields; uniqueness per account (raises `ActiveRecord::RecordNotUnique`) and reuse across accounts;
- unread/recency scopes; idempotent `mark_read!`;
- optional actor + nullify on actor deletion;
- `ON DELETE CASCADE` removes notifications and preferences with the account;
- preference defaults, cadence validation, mute-array validation, `event_enabled?`.

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/notification_test.rb test/models/notification_preference_test.rb
```

Result: **passing** (see Phase 11 for the consolidated run).

## 4. Exit criteria

| Criterion | Result |
|---|---|
| Migration applies cleanly | ✅ `bin/rails db:migrate` succeeded |
| Reversible / additive | ✅ `create_table` + `add_index` + `add_check_constraint` only; no existing table altered |
| Indexed unread queries | ✅ `index_notifications_inbox` |
| Recipient isolation | ✅ every row keyed to `account_id` |
| Duplicate prevention | ✅ unique `(account_id, event_key)` |
