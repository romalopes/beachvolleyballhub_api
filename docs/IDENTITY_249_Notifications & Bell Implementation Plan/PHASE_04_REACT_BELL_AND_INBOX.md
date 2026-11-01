# Phase 4 — React bell and inbox

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §7
**Status:** Complete.

Repository: `beachvolleyballhub` (React 19 + TypeScript + Vite).

## 1. Delivered files

| File | Purpose |
|---|---|
| `src/api.ts` | `AppNotification` / `NotificationPreference` types + `api.notifications`, `unreadNotificationCount`, `markNotificationRead`, `markAllNotificationsRead`, `notificationPreferences`, `updateNotificationPreferences` |
| `src/services/notificationEvents.ts` | Tiny app-level pub/sub so the bell refreshes when the inbox changes read state |
| `src/components/NotificationBell.tsx` | Header bell: unread badge + recent-notifications dropdown |
| `src/pages/Notifications.tsx` | Full inbox: list, unread filter, mark-read, mark-all, pagination, empty/loading/error |
| `src/components/NotificationPreferencesPanel.tsx` | Channel switches + mute list (used on the Account page) |
| `src/App.tsx` | Bell in the mobile header; `/notifications` route (authenticated) |
| `src/components/Sidebar.tsx` | Bell in the desktop sidebar logo row |
| `src/pages/Account.tsx` | Renders `NotificationPreferencesPanel` |
| `src/App.css` | Bell, dropdown, inbox and preference styles |

### Diagnostic: "Send Test Notification" (API Health page)

A manual trigger on `/settings/api-health` (`Write Operations (Manual)`) proves the bell
actually picks up a new row, without hand-crafting a training or membership transition:

| Layer | Artefact |
|---|---|
| Backend | `POST /api/v1/health/notifications/test` → `HealthController#send_test_notification` (admin-only, added to the existing `authorize_admin!` list) |
| Check | `apiHealthConfig.ts` → `{ id: "send-test-notification", … requiresManualTrigger: true }` |
| Runner | `healthRunner.ts` → `runNotificationSendFlow` |
| UI | `components/settings/apiHealth/NotificationSendSandbox.tsx` |

Behaviour worth noting:

- The endpoint creates a **real** notification for the **caller's own** account via
  `Notifications::Publisher` — no account id is accepted, so it can never target somebody else.
- It therefore exercises the **real pipeline**: the preference check and the dedupe key. An account
  with in-app notifications switched off gets `200 { status: "skipped", reason }` and **no row**,
  and the panel says so rather than pretending the bell moved.
- The dedupe key is minted per click (`health-test:<uuid>`), so the second click creates a second
  row — a fixed key would make every click after the first a silent no-op.
- On success the sandbox calls `emitNotificationsChanged()`, so the header badge moves
  **immediately** instead of waiting for the 45s poll.
- The response echoes `unread_count`, making the check self-verifying.
- Unlike `send_test_email`, this flow attaches `X-Test-Access-Token` when one is held, because the
  endpoint is not exempt from the private test-access gate. (The email flow has the same gap and was
  deliberately left untouched here.)

## 2. Behaviour against the plan's checklist

- ✅ **Authenticated only** — the bell renders `null` when `useAuth().user` is null.
- ✅ **Unread badge** — hidden at `0`, capped at `99+`.
- ✅ **Dropdown** — 8 most recent; "Mark all read"; "View all notifications" link to the inbox.
- ✅ **Inbox** — paginated, `Unread only` filter, per-row and bulk mark-read, empty/loading/error states.
- ✅ **Click a notification** — marks read (best-effort) then navigates to `target_path`.
  `target_path` is an **internal route only** (the API never emits an absolute URL), so the click
  cannot become an open redirect.
- ✅ **Polling** — every 45 s **only while the tab is visible** (`visibilitychange`), plus refresh on
  window focus, route change and the app-level read-state signal. No polling without a user.
- ✅ **No second fetching stack** — reuses the project's `fetch` client; no TanStack Query added.
- ✅ **Accessibility** — `aria-label` including the unread count, `aria-haspopup`/`aria-expanded`,
  `role="dialog"` with an accessible name, Escape and outside-click to close, focus-visible outlines,
  touch-friendly targets.
- ✅ **Dropdown placement** — the panel lines up with the bell's **left** edge in the sidebar
  (which sits near the left of the screen, so the panel opens rightwards into the page) and with its
  **right** edge in the mobile header (so it opens leftwards). Anchoring the sidebar panel the wrong
  way pushed it off the left edge; `align` is therefore an explicit prop. The list also caps its
  height against the viewport so a short window cannot push the panel off the bottom.
- ✅ **Mobile** — bell in the mobile header (the sidebar becomes an off-canvas drawer there and its
  bell is hidden to avoid a duplicate that would open past the drawer's right edge); inbox rows stack
  on narrow screens.

## 3. Lint/type notes

The project enables the React Compiler ESLint rules (`react-hooks/set-state-in-effect`). Both the
bell and the inbox therefore fetch **inside the effect** and set state only from the response
callbacks, matching the existing screens (`Training.tsx`, `PlacesToPlay.tsx`) — rather than calling
a `useCallback` loader that sets loading synchronously. `tsc -b` and `eslint` are clean.

## 4. Tests

`src/components/NotificationBell.test.tsx` (6), `src/pages/Notifications.test.tsx` (5),
`src/components/NotificationPreferencesPanel.test.tsx` (4),
`src/components/settings/apiHealth/NotificationSendSandbox.test.tsx` (6):

- badge count renders; dropdown opens and lists notifications; mark-all clears the badge;
  bell renders nothing without a user; the panel opens **leftwards** by default (header) and
  **rightwards** when `align="left"` (sidebar);
- inbox lists rows, empty state, unread filter request shape, single + bulk mark-read;
- preferences load, save an email switch, save a mute, surface a load failure;
- the API Health diagnostic sends a notification, reports PASS with the bell's unread count, and
  emits the bell-refresh signal **only** when a row was really created.

Run:

```bash
npx vitest run src/components/NotificationBell.test.tsx \
                 src/pages/Notifications.test.tsx \
                 src/components/NotificationPreferencesPanel.test.tsx \
                 src/components/settings/apiHealth/NotificationSendSandbox.test.tsx \
                 src/pages/settings/ApiHealth.test.tsx
```

Result: **27 passed** (21 notification-surface + 6 API Health page, including the diagnostic).

## 5. Deliberately not implemented

- **Playwright E2E** (plan §7/§13) — no Playwright harness exists in this repository (only Vitest +
  Testing Library). Adding one is out of scope for this change; the manual acceptance checklist is in
  Phase 11.
- **Optimistic mark-read rollback** — the inbox refetches after a read action, so a failure simply
  leaves the row unread; no optimistic UI was added (the plan listed it as a test target, not a
  requirement).

## 6. Exit criteria

| Criterion | Result |
|---|---|
| Bell + dropdown + inbox shipped | ✅ |
| Unread count, mark-read, mark-all | ✅ |
| Polling while visible; paused otherwise | ✅ |
| Auth-aware; safe navigation | ✅ |
| Accessible + responsive | ✅ |
| Unit tests | ✅ 13 passing |
