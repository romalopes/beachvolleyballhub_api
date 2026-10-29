# Beach Volleyball Hub — Functional Testing and Coverage Implementation Plan

**Date:** 29 October 2026  
**Repositories:** https://github.com/romalopes/beachvolleyballhub_api and https://github.com/romalopes/beachvolleyballhub_frontend

> **Verification status:** The repositories could not be inspected directly in this session (GitHub connectivity unavailable). This is an architecture-informed implementation plan, not a verified inventory of existing files, tests or dependencies. Phase 0 requires an actual repository audit; do not assume suggested names or features already exist.

## Objectives

- Add reliable backend unit, request/integration and authorization tests.
- Add frontend component, hook and interaction tests.
- Add cross-stack Playwright end-to-end tests for critical journeys.
- Measure **line and branch** coverage separately in both repositories, including previously untested files.
- Introduce non-regressing CI coverage gates and visible HTML/LCOV reports.
- Prevent false confidence: coverage measures execution, not quality; maintain a risk-based feature matrix and mutation testing for selected critical rules.

## Recommended stack (subject to Phase 0)

| Layer | Preferred tools | Purpose |
| --- | --- | --- |
| Rails | Keep existing Minitest or RSpec; SimpleCov | Models, services, requests, jobs, authorization, line/branch coverage |
| Rails data | Existing factories/fixtures; add FactoryBot only if justified | Deterministic test data |
| React + TypeScript + Vite | Vitest, React Testing Library, user-event, MSW, `@vitest/coverage-v8` | Components, hooks, mocked API flows, line/branch/function coverage |
| Browser | Playwright Test | Real browser + test Rails API + test PostgreSQL |
| CI | GitHub Actions | Backend/frontend/E2E jobs, artifacts, gates |
| Optional | Codecov or equivalent | Historical coverage dashboard; not required for core solution |

Avoid external paid services. Use test-only secrets, no production credentials, and never run destructive tests against production NeonDB, R2, Render, Cloudflare or email accounts.

## Phase 0 — Audit the real repositories

1. Check backend `Gemfile`, `Gemfile.lock`, `test/`, `spec/`, `config/database.yml`, `config/routes.rb`, `app/models`, `app/controllers`, `app/policies`, `app/services`, `app/jobs`, `.github/workflows`, CI scripts and Docker setup.
2. Check frontend `package.json`, lockfile, `vite.config.*`, `src/`, existing tests, route definitions, API client, auth provider, `.github/workflows`, and Playwright configuration.
3. Identify actual entities, API routes, permissions, feature flags and unfinished features. Record test counts and initial coverage (including files with zero tests).
4. Run existing tests locally; record failures before changing production code. Preserve framework and package manager unless migration is justified.
5. Produce `docs/testing/TEST_AUDIT.md`, `docs/testing/TEST_MATRIX.md` and a list of prioritized gaps.

**AI prompt:**
> Inspect both Beach Volleyball Hub repositories in full. Do not assume Minitest/RSpec, npm/pnpm or the presence of any particular feature. Inventory test frameworks, current test files, CI, models, controllers, React routes/components and authorization implementation. Run existing tests and report baseline failures and coverage. Produce TEST_AUDIT.md and a prioritized TEST_MATRIX.md mapping real endpoints and screens to test levels. Do not change application behavior in this phase.

**Acceptance:** audit names verified paths and commands; baseline failures separated from new work.

## Phase 1 — Backend coverage foundation

1. Retain current Rails test framework. Add `simplecov` in the test group if absent.
2. Initialize SimpleCov **before loading Rails/application code** in the test entrypoint. Enable branch coverage. Include `app/` files not touched by tests (verify SimpleCov tracking configuration against the actual app structure).
3. Exclude only generated, vendor and test code, not untested application directories.
4. Emit HTML and machine-readable coverage; make reports reproducible and ignored by git.
5. Ensure `RAILS_ENV=test` uses a dedicated PostgreSQL database. Isolate external services (R2, Brevo, Geoapify, Google Maps, weather, IP geolocation, Sentry) with fakes or HTTP stubs.
6. Introduce a documented initial minimum based on the measured baseline; increase gradually. Add branch thresholds separately and enforce no coverage regression in PRs.
7. Ensure CI runs schema setup and tests without needing live production integrations.

**AI prompt:**
> Using the existing backend test framework, configure SimpleCov line and branch coverage before Rails loads, include all relevant app files, produce HTML and machine-readable reports, and document exact local commands. Keep a separate test database, stub network integrations, and add a conservative baseline gate without breaking existing tests. Show changed files and demonstrate the reports.

**Acceptance:** clean test run; line and branch coverage reports include zero-hit app files; no production network calls.

## Phase 2 — Backend domain and authorization tests

Prioritize based on real implementation and risk:

| Area | Core scenarios |
| --- | --- |
| Account identity | Signup/login/logout, invite and claim, duplicate email, expired/reused token, password setup/reset, disabled accounts |
| Roles and permissions | Guest/player/coach/curator/admin, explicit permission overrides, tenant/organization boundaries, denial and escalation attempts |
| Profiles | Account with multiple player/coach profiles, claim approvals, ownership changes, cross-profile access |
| Organization hierarchy | International/national/state/club/group relationships, memberships, visibility, invalid parentage |
| Training | Session CRUD, coach/group permissions, attendance, location, timezone, conflict handling |
| Recurring sessions | Template generation, date boundaries, duplicates, partial cancellation, bulk deletion and preservation of manually edited sessions |
| Assessments | Templates, weights/scales, coach independence, multi-player sessions, consolidation, CSV import/export, malformed input |
| Drills and media | Schema validation, player limits, video references, storage failures, unauthorized access |
| Tournaments | Eligibility, registration, participant changes, scheduling, visibility and organization restrictions |
| Locations | Geocoding fallbacks, lat/lon validation, court/sub-location, org/session/tournament linkage |
| Analysis | Video URL/upload, notes, comments, player association, session/tournament links, assessment handoff, access control |
| Notifications/email | Invitation delivery job, retries, idempotency, provider failures and suppressed duplicate messages |
| Weather and external data | Cache behavior, missing location, provider timeout, unavailable forecast, safe fallback advice (if implemented) |
| Background jobs/storage | Retries, duplicate execution, cleanup, ActiveStorage/R2 stubs, backup boundaries |

For every implemented endpoint, test authenticated success, anonymous denial, wrong-role denial, wrong-tenant denial, validation errors, missing records and pagination/filtering where relevant. Assert response body and persisted effects, not merely HTTP status.

**AI prompt:**
> From the verified route and policy inventory, write backend model/service/request tests by feature. First implement a shared authorization matrix covering guest, player, coach, curator and admin plus per-permission overrides and organization scope. Then add positive, negative, boundary and failure tests for accounts, profiles, organizations, training, assessments, drills, tournaments, locations and analysis where these exist. Avoid changing behavior to make tests pass; report suspected defects separately. Use deterministic factories/fixtures and isolated dependencies.

**Acceptance:** all existing high-risk authorization rules and critical mutations have tests; each API feature has a documented owner and test mapping.

## Phase 3 — Frontend coverage foundation

1. Keep existing frontend package manager and test framework where suitable; otherwise add Vitest, React Testing Library, `user-event`, `jest-dom`, MSW, jsdom and compatible V8 coverage plugin.
2. Add test setup for router, auth/session, API mocks, date/time and deterministic data.
3. Configure coverage for **all application source files**, including untested files; exclude only generated output, declaration files and test utilities as appropriate.
4. Output text, HTML and LCOV coverage; track lines, branches, functions and statements.
5. Add scripts equivalent to `test`, `test:run`, `test:coverage` and `typecheck`, adjusted to the existing conventions.
6. Establish measured baseline thresholds and ratchet them upward; avoid immediately imposing arbitrary 90% gates.

**AI prompt:**
> Audit the existing React/Vite frontend testing setup and retain working conventions. Configure Vitest, Testing Library, user-event, MSW and V8 coverage with all source files included. Create reusable render helpers for router/auth and mocked API handlers. Add scripts and document how to inspect HTML/LCOV reports. Do not mock away the component behavior being tested.

**Acceptance:** headless tests pass, reports include untested files, no live API needed for component tests.

## Phase 4 — Frontend functional test suites

Prioritize verified pages/components:

- Login, invitation acceptance, account claim, profile switching and access-denied states.
- Role-aware sidebar, routes, organization membership and permission overrides.
- Training calendar, session editor, recurring template creation/cancellation and location selection.
- Assessment forms, weighted scores, multi-player selection, CSV import validation and result views.
- Drill builder validation, skill filters, media URL/upload states.
- Tournament registration, schedules and participant lists.
- Location map and court selector: mock Maps SDK boundaries, test accessible fallback and coordinates.
- Analysis creation, video list, comments and assessment handoff.
- Weather widget (if implemented): loading, forecasts, error states and condition-based advice.
- Generic forms: required fields, keyboard access, loading, empty/error states, search/filter/sort/pagination and optimistic updates.

**AI prompt:**
> Use the audited component and route list to write Vitest/Testing Library interaction tests for critical user journeys. Exercise user behavior and accessible UI rather than implementation details. Use MSW for API success, 401/403/422/500, timeouts and empty responses. Cover each role's visible actions and protected routes. Group tests by actual feature directories and update the coverage matrix.

**Acceptance:** important forms, navigation, access restrictions and error states have assertions.

## Phase 5 — Cross-stack Playwright E2E

1. Run a **local/CI test stack**: React dev/preview server, Rails API, isolated PostgreSQL; seed deterministic accounts and orgs. Avoid shared production environments.
2. Use Playwright fixtures or API setup for accounts, profiles, coaches and organizations; do not share mutable state across parallel tests.
3. Cover browser journeys: login/invite, profile claim, create organization/group, coach schedules recurring training, player views training, coach records assessment, create drill, tournament enrollment, analysis-to-assessment handoff.
4. Test negative journeys: guest forbidden, cross-organization access, invalid data, expired invitation, API failure and network interruption.
5. Capture trace, screenshots and videos on failures; run Chromium on PRs and broader browser matrix nightly if justified.
6. Keep external maps/weather/email/storage deterministic with test doubles. Add separate limited integration smoke tests for provider configuration, never on every PR.

**AI prompt:**
> Configure Playwright against a dedicated Rails test API and React frontend with isolated PostgreSQL and seeded fixtures. Implement stable, accessible-locator-based E2E tests for the top business-critical journeys found in the repository audit. Use deterministic setup/cleanup and CI-safe environment variables. Add failure traces/screenshots, retries only for CI flakiness, and instructions for local debugging. Never point tests at production.

**Acceptance:** critical journeys pass locally and in CI without third-party services.

## Phase 6 — CI/CD and reporting

- Separate backend unit/request, frontend unit/component and Playwright E2E GitHub Actions jobs.
- Install dependencies using the actual lockfiles; cache dependencies, not mutable databases.
- Start isolated PostgreSQL service for Rails and E2E; apply schema/migrations as appropriate.
- Fail PRs on tests, typechecking and coverage gates; upload coverage HTML/LCOV and Playwright traces as artifacts.
- Enforce coverage per repository, not a misleading merged percentage. Optional Codecov upload should not be required for tests to pass.
- Introduce branch protection after jobs are stable; nightly full E2E and weekly selected mutation tests.
- Do not expose secrets to untrusted PR workflows.

**AI prompt:**
> Build GitHub Actions workflows for the existing backend/frontend tooling. Add independent test, coverage, typecheck and Playwright jobs; PostgreSQL service, isolated environment variables, artifact uploads and stable caching. Enforce baseline line/branch thresholds and show how to raise them safely. Explain how to configure required checks and avoid leaking secrets in fork PRs.

**Acceptance:** PR checks are reproducible; coverage reports and failed E2E traces are downloadable.

## Phase 7 — Coverage ratchet and quality controls

### Suggested targets (aspirational, not current measurements)

| Category | Initial milestone | Long-term target |
| --- | --- | --- |
| Backend lines | measured baseline + 10 percentage points | 90% |
| Backend branches | measured baseline + 10 percentage points | 85% |
| Frontend lines | measured baseline + 10 percentage points | 85% |
| Frontend branches | measured baseline + 10 percentage points | 80% |
| Authentication/authorization rule matrix | 100% of identified critical rules | maintain 100% |
| E2E critical journeys | 5 stable journeys | all critical journeys |

The initial gate must not exceed what existing code can currently achieve without planned remediation. Define a **new/changed code** target of 90% lines and 85% branches where practical, with documented exceptions. Report uncovered files and critical missing scenarios, not just aggregate percentages. Add mutation tests selectively to authorization and assessment calculations to detect weak assertions.

**AI prompt:**
> Analyze SimpleCov and Vitest coverage reports together with TEST_MATRIX.md. Identify untested files, untested branches and missing negative cases. Prioritize by security and business impact, propose the next 10 highest-value tests, and increase thresholds only after those tests pass. For selected authorization and scoring rules, use mutation testing or deliberately faulty implementations to verify tests detect regressions.

**Acceptance:** coverage trends upward without weakening assertions or hiding application code from reports.

## Phase 8 — Documentation, rollout and maintenance

- Create `docs/testing/README.md`, `TEST_AUDIT.md`, `TEST_MATRIX.md`, `COVERAGE_POLICY.md`, `E2E_RUNBOOK.md`.
- Make test-writing part of the definition of done: every bug fix adds a regression test; every endpoint has permission tests; every important screen has success/error tests.
- Review flaky tests and test runtime monthly; prefer deterministic clocks and isolated fixtures.
- Audit new routes/components each release to avoid orphaned untested features.
- Track known coverage exceptions with rationale and expiry.

**AI prompt:**
> Consolidate the implemented test infrastructure into a developer testing guide with exact verified commands, CI troubleshooting, environment setup, coverage report locations, feature-to-test matrix, baseline and thresholds. Provide a phased PR sequence with acceptance criteria and identify any deferred gaps. Ensure the docs reflect the repository state, not assumptions.

## Suggested PR sequence

1. `test/audit-and-baseline` — verified inventory and matrix.
2. `test/backend-coverage-foundation` — SimpleCov, isolated services, CI baseline.
3. `test/backend-auth-organization` — role/tenant/claim tests.
4. `test/backend-training-assessment` — core coaching logic.
5. `test/backend-other-domains` — tournaments, drills, analysis, locations and integrations.
6. `test/frontend-coverage-foundation` — Vitest, MSW, CI.
7. `test/frontend-critical-flows` — forms, permissions, training, assessments.
8. `test/e2e-critical-journeys` — Playwright with isolated full stack.
9. `test/coverage-ratchet` — thresholds, reports, documentation.

## Definition of done

- Both repositories have passing CI test suites and reproducible coverage reports.
- Untested application files count toward coverage.
- Critical authorization and cross-tenant rules have positive and negative tests.
- Critical end-to-end flows pass without using production services.
- Coverage thresholds are enforced, documented and incrementally improved.
- Developers can run tests locally with one documented command per repository.
