# Phase 0 — Audit and Wine Words parity mapping

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Issue:** [romalopes/beachvolleyballhub_api#249](https://github.com/romalopes/beachvolleyballhub_api/issues/249)
**Status:** Complete — audit performed against the local working copies.

## 1. Repositories and revisions audited

| Repository | Local path | Revision at audit |
|---|---|---|
| Beach Volleyball Hub API | `beachvolleyballproject/beachvolleyballhub_api` | `b28475f` (`database check and pundit`) |
| Beach Volleyball Hub frontend | `beachvolleyballproject/beachvolleyballhub` | `2bb3064` (`database check and pundit`) |
| Wine Words API (reference) | `wine_project/wine_words_api` | local working copy |
| Wine Words frontend (reference) | `wine_project/wine_words` | local working copy |

## 2. Verified environment (replaces the plan's assumptions)

The plan was written as a proposal and explicitly asked for code-level verification. The
following were confirmed by inspection, not assumed:

| Concern | Plan assumption | **Verified reality** |
|---|---|---|
| Rails version | unspecified | Rails **8.1.3.1**, Ruby 3.4.2 |
| Backend test framework | "RSpec" | **Minitest** (`bin/rails test`, `ActionDispatch::IntegrationTest`) |
| Frontend styling | "Bootstrap" | **Custom CSS** (`src/App.css`) + CSS custom properties; no Bootstrap |
| Data fetching | "TanStack Query if used" | **Custom `fetch` wrapper** in `src/api.ts`; no TanStack Query |
| Frontend package manager | "pnpm" | **npm** (`package.json` scripts, `package-lock.json`) |
| Background jobs | "`solid_queue` if compatible" | **`solid_queue` already installed and configured** (`Gemfile`, `config/environments/production.rb:79`) |
| Email transport | "existing Brevo HTTP adapter" | Confirmed: `lib/brevo_delivery.rb`, `lib/mail_transport.rb` |
| Authorization | unspecified | **Pundit** (`app/policies`) plus controller concerns |
| Pagination | unspecified | `app/controllers/concerns/pagination.rb` returning `{ data:, meta: }` |
| Existing notifications | unknown | **None** — no table, model, route, controller or component existed |

## 3. Wine Words reference implementation located

Backend (`wine_words_api`):
- `app/models/notification.rb`, `app/models/notification_event.rb`, `app/models/notification_preference.rb`
- `app/controllers/api/v1/notifications_controller.rb`
- `app/serializers/notification_serializer.rb`
- `app/services/notifications/*` (delivery, event publisher, follower/affected-target resolvers, visibility)
- `db/migrate/*_create_notifications.rb`, `*_create_notification_events.rb`, `*_create_notification_preferences.rb`
- `spec/requests/api/v1/notifications_spec.rb` and related specs

Frontend (`wine_words`):
- `src/components/NotificationBell.tsx`, `NotificationPreferences.tsx`, `Notifications.tsx`
- `src/services/notificationEvents.ts`, `src/types/notification.ts`


## 4. Parity matrix (Wine Words → Beach Volleyball Hub)

| Wine Words path / symbol | Purpose | BVH counterpart | Decision |
|---|---|---|---|
| `Notification` model | Recipient row with read state | `app/models/notification.rb` | **Reimplement** — BVH keys on `Account`, uses `event_key` for dedupe, `jsonb` metadata, `target_path` for safe internal navigation |
| `NotificationPreference` model | Channel switches | `app/models/notification_preference.rb` | **Reimplement** — in-app/email switches + mute list + cadence |
| `Api::V1::NotificationsController` | list / unread_count / mark_read / mark_all_read | `app/controllers/api/v1/notifications_controller.rb` | **Reimplement** — BVH pagination concern, `Current.user.account` scoping, explicit `before_action :require_authentication` |
| `NotificationSerializer` | JSON shape | Inline `serialize` in the controller | **Adapt** — BVH serializes inline in controllers (no `app/serializers` convention) |
| `NotificationBell.tsx` | Header bell + badge + dropdown | `src/components/NotificationBell.tsx` | **Port UX, reimplement** — BVH auth context, `lucide-react` `Bell`, custom API client |
| `Notifications.tsx` | Full inbox | `src/pages/Notifications.tsx` | **Port UX, reimplement** — BVH `Pagination`, `EmptyState`, `LoadingState`, `PageHeader` |
| `NotificationPreferences.tsx` | Preferences UI | `src/components/NotificationPreferencesPanel.tsx` | **Port UX, reimplement** |
| `services/notificationEvents.ts` | App-level refresh signal | `src/services/notificationEvents.ts` | **Reimplement** — same tiny pub/sub idea |
| Wine Words domain event rules | Wine-package deadlines, follows | BVH training + membership workflows | **Reimplement from scratch** — Wine Words rules are domain-specific and do not transfer |
| `Notifications::DeliveryService` / digest jobs | Email delivery | *not implemented* | **Deferred to Phase 8** (worker + provider verification gate) |

## 5. Decisions and corrections to the plan

1. **Test framework** — phase acceptance criteria that referenced RSpec translate to Minitest
   request/model/service tests. All phase reports use the actual commands
   (`bin/rails test`, `npx vitest run`, `npm run build`).
2. **No TanStack Query** — the bell uses the project's own `fetch` client and a small
   pub/sub signal, avoiding a second fetching stack (plan §7 explicitly permits this).
3. **Explicit authentication** — `Api::V1::ApplicationController` calls
   `skip_before_action :require_authentication`, so every new API controller must declare
   `before_action :require_authentication`. This was discovered by inspecting the callback
   chain and is now part of the API phase's contract.
4. **Deduplication via the database, not validations** — `Notifications::Publisher` uses
   `create_or_find_by!`, which requires the unique constraint to be enforced by the index
   rather than a model validation. Recorded in Phase 1.
5. **Solid Queue is already present**, so the plan's "alternative first release" applies
   only to *enabling* async email delivery, not to installing the adapter.

## 6. Exit criteria

| Criterion | Result |
|---|---|
| Exact implementation map | ✅ Section 4 |
| Confirmed API naming | ✅ `/api/v1/notifications*`, `/api/v1/notification_preferences` |
| Deployment feasibility documented | ✅ Phase 12 (worker gate recorded) |
| Compatibility decisions documented | ✅ Section 5 |
| Confirmed no pre-existing notification schema | ✅ Section 2 |
