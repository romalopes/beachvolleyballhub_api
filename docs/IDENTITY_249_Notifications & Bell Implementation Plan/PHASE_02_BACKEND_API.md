# Phase 2 — Backend API

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §5
**Status:** Complete.

## 1. Routes

Added to `config/routes.rb` inside `namespace :api, defaults: { format: :json } → namespace :v1`:

| Method | Route | Controller#action | Behavior |
|---|---|---|---|
| GET | `/api/v1/notifications` | `notifications#index` | Paginated, newest first. Filters: `unread=true`, `event_type=<type>`, `page`, `per_page` |
| GET | `/api/v1/notifications/unread_count` | `notifications#unread_count` | `{ unread_count: n }`; `Cache-Control: private, no-store` |
| PATCH | `/api/v1/notifications/:id/mark_read` | `notifications#mark_read` | Idempotent; own notification only |
| PATCH | `/api/v1/notifications/mark_all_read` | `notifications#mark_all_read` | Marks all own unread rows; returns `{ marked: n }` |
| GET | `/api/v1/notification_preferences` | `notification_preferences#show` | Materialises defaults on first read |
| PATCH | `/api/v1/notification_preferences` | `notification_preferences#update` | Persists channel switches / mutes |

## 2. Controllers

- `app/controllers/api/v1/notifications_controller.rb`
- `app/controllers/api/v1/notification_preferences_controller.rb`

### Security contract (from the Phase 0 audit)

`Api::V1::ApplicationController` calls `skip_before_action :require_authentication`, so the API
is public by default. Both new controllers therefore declare:

```ruby
before_action :require_authentication
```

**Recipient isolation:** every query goes through `Current.user.account.notifications`. No
endpoint accepts an `account_id` from the client, so there is no IDOR surface. A missing or
foreign id returns **404** (never revealing another account's row).

### Response shape

```json
{
  "id": 1,
  "event_type": "training.cancelled",
  "title": "Training cancelled",
  "message": "Serve Reception Training has been cancelled.",
  "target_path": "/training/1",
  "target_label": "Serve Reception Training",
  "metadata": { "starts_at": "…", "ends_at": "…" },
  "read": false,
  "read_at": null,
  "created_at": "2026-11-01T05:00:00.000Z",
  "actor": { "id": 2, "name": "Maria Silva" }
}
```

`index` wraps rows as `{ "data": [...], "meta": { page, per_page, total, total_pages } }`, matching
the shared `Pagination` concern used by every other list endpoint.

## 3. Tests

`test/controllers/api/v1/notifications_controller_test.rb`,
`test/controllers/api/v1/notification_preferences_controller_test.rb`:

- 401 when unauthenticated (both controllers);
- index returns **only** the caller's rows; `unread` and `event_type` filters; pagination meta;
- `unread_count` counts only the caller's unread rows;
- `mark_read` succeeds for own row and returns **404** for another account's row (cross-account IDOR);
- `mark_all_read` touches only the caller's rows;
- preferences: materialised defaults, persistence of switches/mutes, 422 on invalid cadence.

Run:

```bash
bin/rails test test/controllers/api/v1/notifications_controller_test.rb \
               test/controllers/api/v1/notification_preferences_controller_test.rb
```

Result: **passing** (see Phase 11).

## 4. Deliberately not implemented

- `PATCH /:id/dismiss` (plan §5 "optional") — the plan marked it optional and no product
  requirement exists yet. Adding it later is additive and needs no schema change.
- Cursor pagination — the plan allowed "cursor/paginated"; the project's existing offset
  pagination is reused so the SPA's shared `Pagination` component works unchanged.

## 5. Exit criteria

| Criterion | Result |
|---|---|
| Authenticated every endpoint | ✅ |
| Client-supplied `account_id` never trusted | ✅ scoped through `Current.user.account` |
| Missing/unauthorized id does not leak | ✅ 404 |
| Request tests for auth / cross-account / pagination / filters / idempotency | ✅ |
