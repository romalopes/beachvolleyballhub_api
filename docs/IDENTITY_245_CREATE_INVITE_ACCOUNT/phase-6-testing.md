# Phase 6: Comprehensive Testing

**Status:** Not Started ⭕

## 6.1 Unit Tests (AccountInvitation model)
- Valid email format validation
- Token digest uniqueness
- Expires_at default (7 days)
- `accepted?`, `revoked?`, `expired?` methods
- `accept!` method behavior (expired/used checks)
- Scope: `pending`, `used`, `for_email`

## 6.2 Unit Tests (AccountInvitationsMailer)
- Delivery to correct email
- Contains acceptance link with fragment token
- Mailer preview works

## 6.3 Integration Tests (Test Matrix)
All scenarios must pass:

| Scenario | Expected Outcome |
|----------|-----------------|
| Admin creates invitation with email+send_invitation=true | User+Account+ContactDetail created + Invitation email sent |
| Invitee accepts invitation sets password | User verified, logged in, invitation marked accepted |
| Accept expired invitation | Error shown, no state change |
| Accept already-used invitation | Error shown, no state change |
| Resend invitation (previous revoked) | New invitation created, old one invalidated |
| Revoke invitation | Status=revoked, AdminActivity created |
| One active invitation per email (scope constraint) | Second invitation for same email fails/updates |

## 6.4 Test Fixtures (update if needed)
- `accounts.yml`: May need invitation-associated fixture
- `users.yml`: May need unverified user fixture
- `contact_details.yml`: Existing should be sufficient