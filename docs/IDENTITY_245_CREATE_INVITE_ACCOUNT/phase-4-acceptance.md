# Phase 4: Invitation Acceptance Route

**Status:** Not Started ⭕

## 4.1 Route: `GET /accept-invitation`

**SPA-Friendly**: Controller renders form; password submission via PATCH request

**Controller**: `AcceptInvitationsController#edit`
- Finds invitation by `token_digest` (matches `SHA256(raw_token)`)
- Renders form where invitee sets password
- Exposes: `invitation.id`, `invitee_email`

**Form Submission**: `PATCH /accept-invitation/:id`
- Parameters: `password`, `password_confirmation`
- Validations: password match, min length (6 chars)
- On success:
  - Update User: `password_digest = BCrypt::Password.create(password)`, `is_verified = true`
  - Mark invitation: `status = 'accepted'`, `used_by = user.id`
  - Create User session (login the new user)
  - Redirect to onboarding/dashboard

**Failure Cases**:
- Expired invitation → show error
- Already used invitation → show error
- Password mismatch → re-render form