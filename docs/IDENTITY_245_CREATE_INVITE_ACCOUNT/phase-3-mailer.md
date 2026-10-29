# Phase 3: AccountInvitation Mailer

**Status:** Not Started ⭕

## 3.1 Mailer: `AccountInvitationsMailer`

**Method**: `invitation(invitation, raw_token)`

**Purpose**: Send single-use invitation email with password-set link

**Email Content**:
- Subject: "You're invited to join BeachVolleyballHub"
- Body: Welcome text + link to `/accept-invitation?token=<raw_token>`
- The token is placed in URL **fragment** (e.g., `/accept-invitation#token=abc123`)
- This prevents token from appearing in server logs/proxy caches

**Rendering**: 
```
AcceptInvitation form where user sets password
```

**Token Security**:
- `raw_token` is the plain-text token sent in email
- `token_digest` stored in database for verification
- Comparison: `Digest::SHA256.hexdigest(raw_token) == invitation.token_digest`

**Mail Transport**: Uses existing configuration (Brevo preferred, Resend fallback, file in dev)

### Test Expectations
- Delivery to invited email
- Contains acceptance link with token
- Token is fragment-based (not path parameter)