# Phase 4 — Internal Contact Messages inbox

**Parent plan:** [beachvolleyballhub_contact_messages_implementation_plan.md](beachvolleyballhub_contact_messages_implementation_plan.md)
**Plan section:** §5.1–§5.4
**Status:** Complete.

## 1. Delivered files (`beachvolleyballhub` frontend)

| File | Purpose |
|---|---|
| `src/pages/settings/ContactMessages.tsx` | Paginated inbox, status tabs, category filter, search |
| `src/pages/settings/ContactMessages.test.tsx` | 9 examples |
| `src/pages/settings/ContactMessageDetail.tsx` | One message, plain-text body, status actions |
| `src/pages/settings/ContactMessageDetail.test.tsx` | 7 examples |
| `src/App.tsx` | `PlatformStaffRoute` guard + two protected routes |
| `src/components/Sidebar.tsx` | Settings → Contact Messages (platform staff only) |
| `src/components/Sidebar.test.tsx` | Visibility matrix for the new links |
| `src/pages/settings/SettingsDashboard.tsx` | "Contact Messages" card on the admin dashboard |
| `src/api.ts` | `adminContactMessages`, `adminContactMessage`, `adminContactMessageUnreadCount`, `adminUpdateContactMessage` |

## 2. Access model

| Role | Sees the link | Can use the API |
|---|---|---|
| Signed-out visitor | Contact page only | No (401) |
| Player / ordinary account | No | No (403) |
| Coach | No | No (403) |
| **Curator** (platform) | Yes | Yes |
| **Admin** | Yes | Yes |

`PlatformStaffRoute` only keeps the UI honest; `ContactMessagePolicy` on the API
is the authority. The link is hidden rather than shown-then-403'd, matching how
the sidebar treats staff-only catalogue pages.

The inbox is deliberately **not** behind `AdminRoute`: Curators answer public
enquiries without needing the admin console.

## 3. Inbox list

- Newest-first, 20 per page, `Pagination` component.
- Columns: status badge, sender (name + e-mail), category label, subject (link to
  detail), received date (`formatApiDate`, the app's timezone-safe formatter).
- Status tabs: All / Unread / Read / Archived, each with a server-provided count.
- Filters: search by name, e-mail or subject (applied on submit) and a category
  select; **Clear** resets everything. Search and filters combine server-side.
- Unread badge in the header (`N unread`) comes from the server counts, which
  never include archived messages (their status is `archived`).
- Loading, empty (different copy when filters are active), error + retry, and a
  responsive layout (the toolbar stacks and the search field widens on mobile).
- The list **never** includes message bodies.

## 4. Detail view

- Sender name and a `mailto:` link, category, received date, status badge.
- The body is rendered as a React text node inside
  `.contact-detail-body { white-space: pre-wrap }`. There is **no**
  `dangerouslySetInnerHTML`; a test posts `<img src=x onerror=alert(1)>` and
  asserts the text is displayed while no `img` element exists.
- Actions: Mark as read / Mark as unread / Archive. Each is disabled when it is
  already the current state (idempotent UI), sends `PATCH` with only `status`, and
  the view updates **only after** the API confirms. A failed request keeps the
  previous state and shows the error.
- Opening a message does not change its status — read state is an explicit action,
  matching the API's side-effect-free `show`.
- A note states replies happen in the user's mail application and messages are
  archived rather than deleted (no reply/delete/attachment features exist).
- Back link to the inbox; loading and error + retry states.

## 5. Tests

```bash
npx vitest run src/pages/settings/ContactMessages.test.tsx \
  src/pages/settings/ContactMessageDetail.test.tsx src/components/Sidebar.test.tsx
```

Inbox: renders sender/category/subject/status, shows the server unread count,
status tab and category filter refetch with the right params and reset paging,
search submits a trimmed term, empty state, error + retry, non-staff sees
"Not authorized." without calling the API, curator is allowed.

Detail: meta + body render, hostile markup is inert, "mark as read" calls the API
and updates the UI only after confirmation, archive works, a failed action keeps
the previous state, load error + retry, non-staff denied.

Sidebar: Contact link visible signed-out; Contact Messages visible to admin and
curator, hidden from coach, player and signed-out visitors.

## 6. Exit criteria

| Criterion | Result |
|---|---|
| Only authorized platform Admins/Curators see and access the inbox | ✅ |
| Organisation-only Curators and Coaches do not gain access | ✅ (no such role can satisfy the check) |
| Backend authorization authoritative | ✅ |
| List newest-first and paginated | ✅ |
| Search and filters work together | ✅ |
| Detail displays content safely as plain text | ✅ |
| Status actions update the UI after server confirmation | ✅ |
| Archived messages excluded from the unread count | ✅ |
| Unauthorized users do not reach the page | ✅ (guard + 403/404 from the API) |
| Mobile layout remains usable | ✅ |
