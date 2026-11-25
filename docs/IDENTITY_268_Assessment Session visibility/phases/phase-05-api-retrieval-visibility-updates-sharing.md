# Phase 5 — API Retrieval, Visibility Updates & Sharing Links

**Status:** ✅ Complete (24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 5)
**Depends on:** Phase 4 complete

## Goal

Implement the API endpoints for:
1. Slug-based retrieval (`GET /api/v1/assessment_sessions/:public_slug`)
2. Share token access (`GET /api/v1/assessment_sessions/share/:share_token`) — unauthenticated
3. Visibility updates via existing `PATCH /api/v1/assessment_sessions/:id`
4. Share link regeneration (`POST /api/v1/assessment_sessions/:id/regenerate_share_link`)

## Implementation checklist

- [x] Add new routes for slug and share-token endpoints (before resources block to avoid :id conflict)
- [x] Add `show_by_slug` action (authenticated, uses `public_slug`)
- [x] Add `show_by_share_token` action (NO auth, uses `share_token`, allows unauthenticated access)
- [x] Add `regenerate_share_link` action (management auth + unlisted only)
- [x] Ensure `update` action handles `visibility` param and returns `visibility`, `public_slug` in response
- [x] Share token response: `{ "share_url": "..." }` only once (200 OK)
- [x] Share token endpoint: 404 for invalid/revoked/wrong-visibility tokens (no existence disclosure)
- [x] Cache headers: `Cache-Control: private, no-store` for share endpoint
- [x] Serializer: include `visibility`, `public_slug`; never expose `share_token_digest`
- [x] Tests: request specs for all new endpoints + edge cases

## Route additions

```ruby
# config/routes.rb
# Slug-based lookup (authenticated, uses public_slug instead of id)
# Must come BEFORE resources :assessment_sessions to avoid :id conflict
get "assessment_sessions/:public_slug", to: "assessment_sessions#show_by_slug", as: :assessment_session_by_slug

# Share-token lookup (UNAUTHENTICATED, uses raw share token)
# Must be placed before the resources :assessment_sessions to avoid conflicts with :id
get "assessment_sessions/share/:share_token", to: "assessment_sessions#show_by_share_token", as: :assessment_session_by_share_token

resources :assessment_sessions, only: %i[index show create update destroy] do
  member do
    # ... existing routes ...
    post :regenerate_share_link
  end
end
```

## Response shapes

### Standard show (ID or slug) — 200 OK
```json
{
  "assessment_session": {
    "id": 123,
    "public_slug": "tuesday-squad-aBc123",
    "visibility": "internal",
    "name": "Tuesday squad screening",
    ...
  }
}
```

### Share token access — 200 OK (restricted payload)
```json
{
  "assessment_session": {
    "id": 123,
    "public_slug": "tuesday-squad-aBc123",
    "visibility": "unlisted",
    "name": "Tuesday squad screening",
    "coach_profile": { "id": 1, "display_name": "Maria Silva" },
    "participants": [...],
    "definition": {...}
  }
}
```

### Regenerate share link — 200 OK
```json
{ "share_url": "https://app.example.com/assessments/share/AbCdEfGhIjKlMnOpQrStUvWx" }
```

### Errors
- 404 Not Found: unknown slug, invalid/expired/revoked token, wrong visibility for token
- 403 Forbidden: authorization failure (management actions)
- 422 Unprocessable: invalid visibility value, cannot regenerate link when not unlisted

## Files touched

- `config/routes.rb` — added slug and share-token routes before resources block
- `app/controllers/api/v1/assessment_sessions_controller.rb` — added `show_by_slug`, `show_by_share_token`, `regenerate_share_link` actions; updated `serialize` to include `visibility` and `public_slug`; added `allow_unauthenticated_access` for share token endpoint
- `app/policies/assessment_session_policy.rb` — added `show_by_slug?` alias to `show?`
- `test/controllers/api/v1/assessment_sessions_controller_test.rb` — 18 tests covering all new endpoints + edge cases

## Acceptance criteria — all verified

- [x] `GET /api/v1/assessment_sessions/:public_slug` works with auth, returns full payload per `show?`
- [x] `GET /api/v1/assessment_sessions/share/:share_token` works WITHOUT auth, returns restricted payload per visibility rules
- [x] Invalid/revoked/wrong-visibility tokens return 404 (no existence disclosure)
- [x] `PATCH /api/v1/assessment_sessions/:id` accepts `visibility`, returns updated fields including `visibility` and `public_slug`
- [x] `POST /api/v1/assessment_sessions/:id/regenerate_share_link` returns `{ share_url }` once, invalidates old token
- [x] Share token NOT exposed in any response except regeneration
- [x] Cache-Control: private, no-store on share endpoint
- [x] All tests pass (18 controller tests, 27 model tests, 28 policy tests)