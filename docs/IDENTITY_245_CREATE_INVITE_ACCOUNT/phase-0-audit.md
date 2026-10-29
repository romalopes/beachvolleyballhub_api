# Phase 0: Repository Audit & Design Constraints

**Status:** Completed ✓

## 0.1 Repository Structure Inspection

### Backend (beachvolleyballhub_api - Rails 7+)
- **Models inspected:**
  - `User` - authentication email, password digest, verification, global Roles/UserRoles
  - `Session` - signed cookie/bearer token sessions
  - `Account` - belongs to User, has required ContactDetail, optional AccountAddress
  - `ClaimInvitation` - for profile claims (PlayerProfile/CoachProfile), NOT account activation
  - `AdminActivity` - audit records
  - `ContactDetail` - first_name, last_name, email, phone, date_of_birth
  - `PlayerProfile`, `CoachProfile` - optional volleyball identities linked to Account

- **Controllers inspected:**
  - `AccountsController` - show, update, update_password (authenticated users)
  - `RegistrationsController` - new/create (unauthenticated, creates User+Account+ContactDetail)
  - `Admin::UsersController` - index, add_role, remove_role
  - `TestAccessController` - test access gate

- **Mailers inspected:**
  - `ClaimInvitationsMailer` - profile claim invitations (existing pattern)
  - `ApplicationMailer` - base configuration
  - Others: email_verifications, passwords, profile_claims, security, test_email, training_sessions

- **Routes inspected:**
  - `resource :session`, `resource :registration, only: %i[new create]`
  - Admin namespace: users with roles
  - API v1: registrations, sessions, passwords, email-verifications
  - `resources :memberships` with profile routes
  - `resource :account, only: %i[show update]` (frontend SPA)

- **Test fixtures:** users.yml, accounts.yml, contact_details.yml with pre-seeded data

### Frontend (beachvolleyballhub - React/TypeScript/Vite)
- SPA with Cloudflare Workers and Vercel deployment references
- `index.html` as entry point
- Vite configuration with SSR/SPA fallback considerations

## 0.2 Key Design Constraints (from existing plan)

| Constraint | Current State | Impact |
|---|---|---|
| **User password** | Required for regular registration | Invitation creates User WITHOUT password; invitee sets own password |
| **Email uniqueness** | User.email_address must be unique | Invitation uses separate `invitee_email` on AccountInvitation; User created first without email constraint when no email provided |
| **ClaimInvitation preserved** | Exists for profiles | Must NOT be overwritten; `AccountInvitation` is separate model |
| **Session authentication** | Signed cookie/bearer | New users from invitations get session after password setup |
| **Mail transport** | Brevo preferred, Resend, file (dev) | Use existing transport; new mailer follows ClaimInvitationsMailer pattern |
| **No Person model** | Explicitly forbidden | AccountInvitation has no Person association |
| **Global roles vs organisation roles** | Distinct | Admin invitations don't grant global admin by default |

## 0.3 Database Schema Gaps

**Missing:**
- `account_invitations` table (needs migration)
- `account_invitations` model class
- Admin invitation creation controller/endpoint
- Invitation acceptance route/frontend
- Invitation resend/revoke admin actions

**Existing tables used:**
- `users` - id, email_address, password_digest, email_verified_at, created_at
- `accounts` - id, user_id (unique), contact_detail_id (required), first_name, last_name, phone, date_of_birth
- `contact_details` - id, account_id, first_name, last_name, email, phone, date_of_birth
- `admin_activities` - id, user_id, action, trackable_type, trackable_id, created_at

## 0.4 Migration Safety Check

Before creating any new migration:
1. Verify no existing data conflicts (check current production data)
2. Ensure migration is reversible or well-documented for rollback
3. Confirm `account_invitations` doesn't conflict with `claim_invitations`
4. Add index on `token_digest` (unique) and `invitee_email`

## 0.5 Environment Variables (from .env.example)

| Variable | Current Value | Purpose |
|---|---|---|
| `MAIL_TRANSPORT` | `file` | file/brevo/resend/smtp |
| `MAIL_FROM` | `BVB Project <no-reply@example.com>` | sender address |
| `MAIL_REPLY_TO` | `support@example.com` | reply-to |
| `APP_HOST` | `localhost` | app hostname |
| `FRONTEND_URL` | `http://localhost:5174` | frontend URL for links |
| `BREVO_API_KEY` | (secret) | Brevo API |
| `RESEND_API_KEY` | (secret) | Resend API |
| `SMTP_ADDRESS` | (optional) | SMTP server |
| `SMTP_PORT` | `587` | SMTP port |

## 0.6 Acceptance Criteria Verification (Phase 0)

- [x] Repository architecture documented
- [x] Existing flows preserved (ClaimInvitation, registration, sessions)
- [x] Mail transport configuration identified
- [x] Frontend-backend URLs confirmed
- [x] Test infrastructure located (integration tests in test/integration/)
- [x] No Person model will be created
- [x] AccountInvitation distinct from ClaimInvitation

---
*Phase 0 Complete: Audit summary documented. Ready to proceed with Phase 1: AccountInvitation Model.*