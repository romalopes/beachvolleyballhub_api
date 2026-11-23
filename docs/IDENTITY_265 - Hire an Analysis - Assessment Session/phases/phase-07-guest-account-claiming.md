# Phase 7 — Guest Account Creation & Request Claiming

**Goal:** Allow guest submitters to create an account and claim their previous requests after email verification.

**Prerequisites:** Phase 6 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Controller** | `app/controllers/api/v1/analysis_request_claims_controller.rb` |
| **Service** | Reuse `EmailVerificationService` + `ClaimInvitation` patterns |
| **Mailer** | `AnalysisRequestsMailer.claim_invitation` |
| **Routes** | `POST /api/v1/analysis_requests/:id/claim` |
| **Frontend** | Claim page at `/claim/analysis/:token` |
| **Tests** | Claim flow: token → verify email → link requests |

---

## Claim Flow

1. Guest has request with `guest_email` and `guest_access_token`
2. Guest clicks "Create Account" on guest access page → `/claim/analysis/:guest_access_token`
3. Frontend shows signup form pre-filled with email (read-only)
4. On submit: create User + Account, send verification email
5. After email verified: link all AnalysisRequests with matching `guest_email` to new account
6. Clear `guest_name`, `guest_email`, `guest_access_token` on claimed requests

---

## Controller

```ruby
# app/controllers/api/v1/analysis_request_claims_controller.rb
module Api
  module V1
    class AnalysisRequestClaimsController < ApplicationController
      allow_unauthenticated_access only: [:new, :create]

      # GET /api/v1/analysis_requests/:id/claim?token=xxx
      def new
        @request = AnalysisRequest.find_by_guest_access!(params[:token])
        render json: { guest_email: @request.guest_email, guest_name: @request.guest_name }
      end

      # POST /api/v1/analysis_requests/:id/claim
      def create
        @request = AnalysisRequest.find_by_guest_access!(params[:token])
        user = User.create!(email_address: @request.guest_email, password: params[:password], email_verified_at: nil)
        account = user.create_account!(first_name: @request.guest_name.split.first, last_name: @request.guest_name.split.last, email: @request.guest_email)

        # Send verification email
        EmailVerificationService.send_verification(user)

        # Link request to account (pending verification)
        @request.update!(account: account, guest_name: nil, guest_email: nil, guest_access_token: nil)

        render json: { message: "Account created. Please verify your email." }, status: :created
      end
    end
  end
end
```

---

## EmailVerificationService Integration

```ruby
# After verification (existing EmailVerificationService callback)
def after_verification(user)
  # Link all guest requests with this email
  AnalysisRequest.where(guest_email: user.email_address, account_id: nil)
                 .update_all(account_id: user.account_id, guest_name: nil, guest_email: nil, guest_access_token: nil)
end
```

---

## Frontend

- Page: `/claim/analysis/:token` (React route)
- Form: password + confirm (email pre-filled, read-only)
- On success: redirect to `/my/analysis-requests`

---

## Acceptance Criteria

- [ ] Guest can create account from claim page with pre-filled email
- [ ] Verification email sent via existing `EmailVerificationService`
- [ ] After verification, all matching guest requests linked to new account
- [ ] Guest fields cleared on claimed requests
- [ ] Claimed requests appear in `/my/analysis-requests`
- [ ] `bin/rails test` + `npm run test` pass

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Reuse ClaimInvitation | Direct account creation + EmailVerificationService | Simpler; ClaimInvitation is for coach/player invites |
| Single claim per token | Token invalidated after use | Security |