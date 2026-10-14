## 11. Phase 9 — Security, quality and integration testing

Test across both repos:

- Permissions matrix: guest, Account owner, player, coach, curator, admin, real/effective impersonated user.
- Input validation: URLs, text, malformed dates, unknown zones, invalid division codes, duplicated/foreign IDs, forged ownership.
- Lifecycle: upcoming/ongoing/completed, cancelled/archived, restored, delete unused, unlink archived.
- Time: cross-midnight, multi-day, DST spring/fall, international offset, all-day exclusive end.
- Query correctness: overlapping windows, search escaping, combined filters, stable pagination, 100+ records, stale fetch cancellation.
- DB integrity: duplicate self-links, composite FKs, concurrent division edits, organisation deletion restrictions.
- Performance: eager loading, realistic event counts, query plan checks, frontend bundle impact.
- Regression: training calendar, organisations, accounts, profiles, sign-in and test-access gate.

**AI prompt — end-to-end verification**

Run the full backend Minitest suite, frontend lint/typecheck/Vitest/build and existing E2E tests. Add Playwright E2E flows if the project already uses Playwright, otherwise propose a minimal test harness without disrupting CI. Verify guest discovery, admin creation, multi-division editing, self-link, My Tournaments, archive/unlink, 100+ event calendar pagination, timezone boundaries and unchanged training calendar. Report failures with exact reproduction steps; fix only related regressions. Generate docs/tournament_calendar_v2/test_matrix.md and a concise evidence report with commands and results. Do not claim tests passed unless actually executed.

**Gate:** all test suites pass and no new regressions.