# Phase 2: Admin Account Creation Controller

**Status:** Not Started ⭕

## 2.1 Controller: `Admin::Accounts::InvitationsController`

**New Route**: `POST /admin/accounts/invitation`

**Parameters**:
- `first_name` (string) – for User creation
- `last_name` (string) – for User creation
- `email` (string, optional) – for User + AccountInvitation
- `send_invitation` (boolean) – whether to send invitation email

**Behavior**:
1. **If email present AND send_invitation=true**:
   - Create `User` with: `email`, `first_name`, `last_name`, `is_verified=false`, no password (password_digest = nil)
   - Create `Account` with `user_id`
   - Create `ContactDetail` with required fields
   - Create `AccountInvitation` with token, `invitee_email=email`, `inviter_id=current_admin_id`
   - Send invitation email

2. **If email present AND send_invitation=false**:
   - Create `User`+`Account`+`ContactDetail` without invitation
   - User remains unverified, no password set

3. **If no email**:
   - Create `User`+`Account`+`ContactDetail` without email/invitation
   - Used for creating accounts without email (internal users)

**Atomic Transaction**: All-or-nothing within `create` action

**Response**:
- JSON success with invitation details (if email+invitation)
- JSON error if validation fails
- HTML redirect if from admin UI