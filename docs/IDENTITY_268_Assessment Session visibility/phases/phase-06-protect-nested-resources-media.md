# Phase 6 — Protect Nested Resources & Media

**Status:** ✅ Complete (24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 6)
**Depends on:** Phase 5 complete

## Goal

Ensure nested resources and media are properly protected according to the visibility matrix:
- Participants, scores, ranking payload only visible to authorized viewers
- Media (if any future attachment) protected
- No data leakage in serializers, errors, logs, analytics, exports

## Implementation checklist

- [x] Participant endpoints (`add_players`, `remove_players`, `scores`) - verify they use existing `authorize` and return proper data per visibility
- [x] Ranking endpoint - verify restricted for share-token access (already excluded from share serializer)
- [x] Serializer audit: ensure no sensitive fields leak in public/unlisted responses (share serializer already restricts)
- [x] Error messages: no internal IDs, tokens, or organization details in error responses
- [x] Logs: verify raw share tokens never logged (model uses digest only)
- [x] Analytics/exports: no share tokens in any export
- [x] Tests: verify nested resource access control (added 10 new tests)

## Key findings from Phase 1 (deviation D4)

AssessmentSession has NO video/attachment surface (videos belong to Analyses). Exposure risks are:
- Serializer fields (`notes`, account names) - already handled in share serializer
- Participants - restricted in share serializer
- Scores/results - management only, not exposed via share token
- Ranking payload - restricted in share serializer
- Analysis-deliverable linkage - not exposed via share token

## Files touched

- `app/controllers/api/v1/assessment_sessions_controller.rb` - verified existing auth, serializers already correct
- `test/controllers/api/v1/assessment_sessions_controller_test.rb` - added 10 new nested resource tests

## Acceptance criteria — all verified

- [x] Participants endpoint returns appropriate data per visibility (full for managers, restricted for share token)
- [x] Scores endpoint properly authorized (management only, correct format validated)
- [x] Ranking endpoint properly authorized (management + visibility-aware via policy)
- [x] No sensitive data in error responses
- [x] No raw tokens in logs (model stores digest only)
- [x] All existing tests pass + new nested resource tests pass (28 controller tests, 28 policy tests, 27 model tests)

## Test results

```
83 runs, 242 assertions, 0 failures, 0 errors, 0 skips
```