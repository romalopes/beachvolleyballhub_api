# Phase 5: Admin Invitation Management

**Status:** Not Started ⭕

## 5.1 Resend Action
- `POST /admin/accounts/invitations/:id/resend`
- Invalidates previous token (marks status='revoked', creates AdminActivity)
- Creates new `AccountInvitation` for same email
- Sends new invitation email
- **Admin notes**: Track resend count in AdminActivity

## 5.2 Revoke Action
- `POST /admin/accounts/invitations/:id/revoke`
- Marks invitation `status = 'revoked'`
- Creates `AdminActivity` record: "Invitation revoked for {email}"
- **Use case**: User requested removal, or invitation stale

## 5.3 Admin Index
- List all invitations with columns: Email, Inviter, Created At, Expires At, Status, Actions
- Filter by: status (pending/accepted/revoked), expired status
- Bulk actions: resend, revoke selected

## 5.4 AdminActivity Records
- Track: who performed action, what, when, related invitation id
- Examples: "Invitation sent to user@email", "Invitation accepted", "Invitation revoked"