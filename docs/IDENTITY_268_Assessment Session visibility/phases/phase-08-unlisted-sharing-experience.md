# Phase 8: Unlisted Sharing Experience

## Summary
Implemented the public share page for unlisted assessment sessions, allowing anyone with a valid share token to view the session without authentication. Added login continuation so users can sign in and be redirected back to the full session view.

## Files Created/Modified

### Frontend (beachvolleyballhub)
| File | Purpose |
|------|---------|
| `src/pages/AssessmentSessionSharePage.tsx` | Public share page for unlisted sessions via share token |
| `src/App.tsx` | Added route `/assessments/share/:shareToken` and import |
| `src/api.ts` | Added `display_name` to `AssessmentSession.coach_profile` type for share serializer response |

### Backend (beachvolleyballhub_api)
| File | Purpose |
|------|---------|
| `app/controllers/api/v1/assessment_sessions_controller.rb` | Already had `show_by_share_token` and `serialize_share` (Phase 5) |

## Implementation Details

### Public Share Page (`AssessmentSessionSharePage.tsx`)
- **Route**: `/assessments/share/:shareToken` (unauthenticated)
- **Data fetching**: Calls `api.assessmentSessionByShareToken(shareToken)` which hits `GET /api/v1/assessment_sessions/share/:share_token`
- **Loading/Error states**: Spinner while loading, friendly error page for invalid/expired/revoked tokens
- **Session display**: Shows session name, date, coach, assessment definition, status badge
- **Participants**: Grid showing player names, scores (overall_score%), and inclusion status (included/incomplete/excluded)
- **Assessment categories**: Lists disciplines with weights
- **Actions**:
  - Share button (Web Share API)
  - Copy link button
  - "Sign in to View Full Session" button for unauthenticated users
  - "View in App" link for authenticated users (deep-links to `/assessment-sessions/:public_slug`)

### Login Continuation
- Share page captures `returnTo` query parameter (defaults to current share URL)
- "Sign in to View Full Session" navigates to `/identity?returnTo=<encoded_url>`
- After login, the Identity page handles the `returnTo` redirect

### Share Token Security
- Backend `show_by_share_token` uses `AssessmentSession.find_by_share_token!` which:
  - Validates token digest (SHA-256)
  - Enforces session is `unlisted`
  - Returns 404 for invalid/expired/revoked/wrong-visibility tokens (no existence disclosure)
- Response uses `serialize_share` which omits:
  - Coach notes
  - Coach account_name
  - Participant account_name
  - Participant missing_reason
  - Full ranking data
  - Consolidations
- Sets `Cache-Control: private, no-store`

### TypeScript Types
- Added `display_name?: string` to `AssessmentSession.coach_profile` type to match share serializer response
- Share serializer returns `coach_profile: { id, display_name }` instead of full profile

## Testing
- Frontend build: ✅ Passes (TypeScript + Vite)
- Backend tests: ✅ 28 controller tests, 55 model/policy tests all passing
- Manual verification: Share page loads correctly for valid tokens, shows error for invalid tokens, login continuation works

## Deviations from Plan
- The share page uses the same route pattern as the weather share (`/assessments/share/:shareToken` vs `/weather/:publicToken`)
- Login continuation uses the existing Identity page returnTo mechanism rather than a dedicated callback

## Acceptance Criteria Met
- [x] Unlisted sessions accessible via share token without authentication
- [x] Share page displays session details, participants, scores, and categories
- [x] Sensitive data (notes, account names, missing reasons) not exposed
- [x] Copy link and native share functionality
- [x] Login continuation redirects back to share page
- [x] Invalid/expired/revoked tokens show generic 404 error
- [x] Cache-Control headers prevent caching