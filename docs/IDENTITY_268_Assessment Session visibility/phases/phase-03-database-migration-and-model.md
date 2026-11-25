# Phase 3 — Database Migration & Model

**Status:** ✅ Complete (24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 3)
**Depends on:** Phase 2 contract approved

## Goal

Introduce the `visibility`, stable `public_slug`, and `share_token_digest` columns safely.

## Implementation checklist

- [x] Migration: add `visibility` (string, default 'internal', not null), `public_slug` (string, unique, not null), `share_token_digest` (string, unique, nullable)
- [x] Migration: backfill `visibility` = 'internal' for all existing rows
- [x] Migration: generate unique `public_slug` for all existing rows (parameterized `title-randomsuffix` pattern, collision-safe)
- [x] Migration: add CHECK constraint for `visibility IN ('public','unlisted','internal','private')`
- [x] Model: `VISIBILITIES = %w[public unlisted internal private].freeze`
- [x] Model: inclusion validation on `visibility`
- [x] Model: `public_slug` uniqueness validation + collision-safe generator (kept stable on title change)
- [x] Model: `share_token_digest` handling — SHA-256 of raw token, never store raw
- [x] Model: `regenerate_share_token!` — atomic replace digest, return raw token once
- [x] Model: `clear_share_token!` — called when visibility leaves 'unlisted'
- [x] Model: `visibility=` setter — clears share token when leaving unlisted (via `before_save` callback)
- [x] Tests: model specs covering all acceptance criteria

## Migration strategy

- Use `add_column` with `default: 'internal'` for visibility
- Add `public_slug` in two steps: nullable first, backfill in batched `find_in_batches`, then `change_column_null` + unique index
- Add `share_token_digest` nullable with unique index (PostgreSQL allows multiple NULLs in unique index)
- Use `SecureRandom.urlsafe_base64(24)` for slug random suffix; retry on collision
- Batched updates to avoid loading all records into memory

## Files touched

- `db/migrate/20261124110000_add_visibility_and_sharing_to_assessment_sessions.rb`
- `app/models/assessment_session.rb`
- `test/models/assessment_session_test.rb`
- `test/fixtures/assessment_sessions.yml` (added `public_slug` to fixtures)

## Acceptance criteria — all verified

- [x] `bin/rails db:migrate` succeeds on development DB
- [x] `bin/rails test test/models/assessment_session_test.rb` passes (27 tests, 80 assertions)
- [x] All existing assessment sessions have `visibility='internal'`, unique `public_slug`, NULL `share_token_digest`
- [x] New records default to `internal`
- [x] Slug stays stable when title changes
- [x] Token generation stores only digest, returns raw once
- [x] Regeneration invalidates previous token
- [x] Leaving unlisted clears digest
- [x] No raw tokens in logs or persisted anywhere
- [x] Related tests pass: `test/models/assessment_session_participant_test.rb`, `test/controllers/api/v1/assessment_sessions_controller_test.rb`

## Deviations from parent plan (Phase 1)

- D1: `visibility` is string column + `VISIBILITIES` constant (not integer enum)
- D2: SHA-256 digest storage (no precedent in codebase)
- D3: No organisation association — handled in policy (Phase 4)