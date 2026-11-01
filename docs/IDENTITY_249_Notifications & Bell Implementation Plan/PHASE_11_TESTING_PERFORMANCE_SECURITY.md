# Phase 11 — Testing, performance and security

**Parent plan:** [BeachVolleyballHub_Notifications_Implementation_Plan.md](BeachVolleyballHub_Notifications_Implementation_Plan.md)
**Plan section:** §13
**Status:** Complete for the implemented scope.

## 1. Commands run and results

### Backend (`beachvolleyballhub_api`)

| Command | Result |
|---|---|
| `bin/rails db:migrate` | ✅ applied (1 migration) |
| `bin/rails test <notification files>` | ✅ **40 runs, 110 assertions, 0 failures, 0 errors** |
| `bin/rails test test/controllers/api/v1/health_controller_test.rb` | ⚠️ 27 runs (19 pre-existing + **8 new**), **3 failures** — the same 3 pre-existing env-dependent tests (Brevo/test-mode mail, DB adapter info); proven identical at baseline |
| `bin/rails test` (full suite) | ⚠️ 1656 runs, 6576 assertions, **17 failures, 4 errors, 1 skip** — **all pre-existing** (see §2) |
| `bin/rubocop` (new/changed files) | ✅ **no offenses** |
| `bin/brakeman --no-pager` | 6 warnings, **none notification-related** (see §4) |

The notification files run above are:
`test/models/notification_test.rb`, `test/models/notification_preference_test.rb`,
`test/services/notifications/`, `test/controllers/api/v1/notifications_controller_test.rb`,
`test/controllers/api/v1/notification_preferences_controller_test.rb`.

### Frontend (`beachvolleyballhub`)

| Command | Result |
|---|---|
| `npx vitest run <notification + api-health files>` | ✅ **27 passed** |
| `npm test` (full suite) | ⚠️ 1166 tests, **3 failed** — **all pre-existing** in `src/pages/Home.test.tsx` (see §2) |
| `npx tsc -b` | ✅ clean |
| `npx eslint <new/changed files>` | ✅ clean |
| `npm run build` | ✅ built |

## 2. Pre-existing failures (proved, not assumed)

Both repositories carry failures that exist **before** this change. They were proven by stashing the
new work and re-running:

| Suite | Pre-existing failures | Proof |
|---|---|---|
| `test/models/account_invitation_test.rb` | 3 | identical failure lines with and without the change |
| `test/controllers/api/v1/groups_controller_test.rb` | 6 | identical failure lines |
| `test/controllers/api/v1/organisations_controller_test.rb` | 7 | identical failure lines (all in the `leave` action, which this change does not touch) |
| `test/services/tournament_division_service_test.rb` | 2 | identical failure lines |
| `test/controllers/api/v1/health_controller_test.rb` | 3 | identical failure lines |
| **Backend total** | **21 (17F + 4E)** | baseline run reported the **same 21** |
| `src/pages/Home.test.tsx` | 3 | identical (3 failed | 5 passed) on a stashed baseline |


## 3. Coverage of the plan's matrices

### Backend matrix

| Plan item | Covered by |
|---|---|
| Model validation, scopes, unread count, unique dedupe key | `notification_test.rb` |
| Request specs: auth, pagination, filters, mark-read, cross-account IDOR | `notifications_controller_test.rb` |
| Recipient resolver: member vs non-member, approvers, actor exclusion, duplicates | `workflow_events_test.rb` |
| Event integration: no-op update, repeat delivery, added participant | `workflow_events_test.rb` |
| Preference enforcement (channels disabled) | `publisher_test.rb`, `notification_preference_test.rb` |
| Privacy: another account's id returns 404; target path is internal-only | `notifications_controller_test.rb` |

### Frontend matrix

| Plan item | Covered by |
|---|---|
| Bell badge, empty/unread states, dropdown, mark-read, mark-all | `NotificationBell.test.tsx`, `Notifications.test.tsx` |
| Network failure handling | bell falls back to 0; preferences panel surfaces the error |
| Keyboard/ARIA | asserted via role/name queries (`aria-label`, `role="dialog"`) |
| Responsive layout | CSS (`.notification-row` stacks < 768px) |

## 4. Security review

| Check | Result |
|---|---|
| IDOR / cross-account reads | ✅ 404 for foreign id; all queries scoped to `Current.user.account` |
| Authentication | ✅ `before_action :require_authentication` on both controllers (required because the API base controller skips it) |
| Open redirect | ✅ `target_path` is an internal route; the API never emits absolute URLs |
| Brakeman | ✅ 6 warnings, **all pre-existing** (`organisations_controller.rb` membership params, `tournaments_controller.rb`, `profile_merge_service.rb`, `profile_claim_candidate_finder.rb`) — none in notification files |
| Cache leakage | ✅ `unread_count` sets `Cache-Control: private, no-store` |
| Mass assignment | ✅ preferences permit an explicit allow-list |

## 5. Performance

- The inbox query is served by the dedicated `index_notifications_inbox` index
  (`account_id, read_at, created_at`), so both the unread count and the newest-first page are indexed.
- `per_page` is clamped by the shared `Pagination` concern (max 100), so a client cannot dump the table.
- The bell uses the single-COUNT endpoint rather than the list.
- Recipient resolution eager-loads `player_profile: :account` / membership accounts to avoid N+1.

## 6. Observability and retention

- **Not implemented:** Sentry tags for event type, delivery metrics, and a retention/purge policy.
  These are recorded as follow-ups rather than guessed at, because the retention window
  ("read notifications older than 180 days" was only an example) needs a product/legal decision.

## 7. Manual acceptance checklist

1. Sign in → the bell appears in the sidebar (desktop) and header (mobile).
2. As a coach, cancel a training with a participant whose player profile is linked to an account →
   that account's bell shows **1**.
3. Open the dropdown → the notification appears; "Mark all read" clears the badge.
4. Open `/notifications` → the row shows; "Unread only" hides it after reading; pagination works.
5. Click the notification → it marks read and navigates to the training.
6. Mute "Training cancellations" in Account → repeat step 2 → **no** new notification.
7. Submit a join request to an organisation that requires approval → the owner sees
   "Membership request"; approving tells the requester.
8. Sign out → the bell disappears; no polling occurs.
9. **Diagnostic shortcut:** on `/settings/api-health`, under *Write Operations (Manual)*, click
   **Send test notification** → it reports PASS with the new unread count, and the header bell badge
   moves **without a page reload** (the sandbox emits the app-level refresh signal). Clicking it
   twice creates two rows. With in-app notifications switched off in Account settings it reports
   FAIL and explains that nothing was created.

## 8. Exit criteria

| Criterion | Result |
|---|---|
| Actual project commands run | ✅ §1 |
| No new test failures | ✅ §2 |
| RBAC/tenant/IDOR audited | ✅ §4 |
| Coverage summary produced | ✅ §3 |
| Manual acceptance checklist | ✅ §7 |

**Conclusion: this change introduces zero new test failures.**
