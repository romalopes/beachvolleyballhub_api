# BeachVolleyballHub — Personalized Weather Advisor Weights

**Status:** Implementation plan (no repository changes applied)  
**Date:** 2026-11-02  
**Repositories:** `romalopes/beachvolleyballhub_api` and `romalopes/beachvolleyballhub_frontend`

## 1. Goals and non-goals

Add a detailed explanation of weather suitability scoring at the **bottom of `/account`**. Let every authenticated account configure five scoring weights using **noUiSlider**. Add a configuration link near the existing weather score area of `WeatherWidget.tsx` (approximately line 166), pointing to `/account#weather-advisor-preferences`. Changes should be reflected in personalized weather assessments without affecting public/guest results or independent safety warnings.

Out of scope: editing factor thresholds, changing weather provider, hiding warnings, organization-level preferences, or replacing the current weather scoring heuristic.

## 2. Verified baseline and audit caveat

The publicly accessible backend `app/services/weather/volleyball_advisor.rb` defines:

```ruby
WEIGHTS = { wind: 0.40, temperature: 0.20, rain: 0.25, uv: 0.05, humidity: 0.10 }.freeze
LABELS = [[85, 'Excellent'], [70, 'Good'], [50, 'Fair'], [30, 'Poor'], [0, 'Unsuitable']].freeze
```

Its `assess(current:, rain_chance_percent: nil)` returns `score`, `label`, `advice`, `warnings`, and `safety_override`. It drops factors with missing measurements and normalizes by the weights of the remaining measured factors. Its warnings are independent of the score. The frontend is React/TypeScript/Vite. **Other exact paths, current controller contracts, account auth hooks, weather widget implementation, and existing tests must be confirmed during Phase 0** rather than assumed.

Sources: `https://github.com/romalopes/beachvolleyballhub_api/blob/main/app/services/weather/volleyball_advisor.rb` and `https://github.com/romalopes/beachvolleyballhub_frontend`.

## 3. Functional requirements and acceptance criteria

1. The `/account` page ends with a section titled **Weather Advisor Preferences**, anchor `id="weather-advisor-preferences"`.
2. The section explains the factor scoring, missing-data normalization, labels, independent warnings, and limitations (coaching heuristic, **not** a safety certification).
3. A logged-in user, irrespective of role or organization, may save only their own five weights.
4. Guest/public weather continues using the default weights and cannot access the preference endpoints.
5. Five noUiSlider controls support whole-number percentages 0–100, summing to exactly 100; paired numeric inputs are keyboard accessible.
6. Save, cancel/discard unsaved changes, and reset to defaults are supported. Loading/error/success states are visible.
7. A **Configure Weather Preferences** link appears in `WeatherWidget.tsx` for all authenticated users and is hidden for guests. It navigates to `/account#weather-advisor-preferences`, then reliably scrolls to the section even if content loads asynchronously.
8. Saving/resetting invalidates personalized score data; other users and guests see no changes.
9. Existing warnings, `safety_override`, advice, score labels, and public API contracts remain backward compatible.
10. Model, service, request, UI and E2E tests cover edge cases and authorization.

## 4. Scoring documentation shown on `/account`

Let factor scores `s_i` be 0–100 and weights `w_i` be percentages. For available measurements with positive weights:

`score = round(sum(s_i * w_i) / sum(w_i))`.

Missing factors are excluded; their weights are not counted. If there are no measured factors **with positive weight**, return an unknown score (`nil`) rather than dividing by zero. **Zero weight is valid** and means that factor does not contribute to the suitability score; warnings still apply.

Defaults: Wind 40%, Temperature 20%, Rain 25%, UV 5%, Humidity 10%.

Labels: Excellent 85–100; Good 70–84; Fair 50–69; Poor 30–49; Unsuitable 0–29; Unknown when insufficient positively weighted measurements exist.

Show the factor score thresholds **from the current Ruby code**, not a hand-maintained guess. Document wind/gust, apparent temperature/temperature fallback, rain chance/precipitation fallback, UV, and humidity. Explain that higher weight means greater influence on the final rating, not a change to the raw weather measurement. Give a concrete, reproducible example and optional factor-by-factor contribution table. Keep warnings visible regardless of user weights.

## 5. Data model and API contract

### Database

Prefer `weather_advisor_preferences` (singular preference record per account):

| Column | Type | Rule |
|---|---|---|
| id | bigint | PK |
| account_id | bigint | NOT NULL; FK to accounts; UNIQUE |
| wind_weight | integer | NOT NULL; 0..100; default 40 |
| temperature_weight | integer | NOT NULL; 0..100; default 20 |
| rain_weight | integer | NOT NULL; 0..100; default 25 |
| uv_weight | integer | NOT NULL; 0..100; default 5 |
| humidity_weight | integer | NOT NULL; 0..100; default 10 |
| created_at / updated_at | datetime | timestamps |

Add Rails validations and PostgreSQL CHECK constraints for 0..100 and total = 100. Use the existing account identity model and deletion behavior; no backfill is necessary. Avoid per-request record creation for accounts using defaults. Prefer an explicit `has_one` association and dependent cleanup consistent with existing patterns.

### Endpoints (adapt namespace to existing routes)

- `GET /api/weather_advisor_preferences`: `{ weights: {wind:40,...}, defaults: {wind:40,...}, customized: false }`.
- `PUT /api/weather_advisor_preferences`: body `{ weights: {wind: 35, temperature: 25, rain: 25, uv: 5, humidity: 10} }`; replace atomically, validate complete five-key payload; return effective preference.
- `DELETE /api/weather_advisor_preferences`: remove custom row, return defaults.

All require authentication; derive `account_id` from server-side session/current account; never accept arbitrary `account_id` from the client. Use consistent 401/403/422 handling and existing serializer conventions. Reject unknown keys, negative/noninteger weights, missing factors and totals != 100. Handle concurrent requests and unique-index races safely.

**Integration:** Trace the existing weather endpoint(s), controller, service and caching. Add optional effective account weights to the existing assessment pipeline without changing guest responses. Do not personalize a globally shared cached response. Prefer caching raw provider weather independently of the account and applying the advisor after retrieving it. If score caching exists, key it by preference identity/version and weather inputs or bypass score caching. Do not expose user preferences in public data.

## 6. UI design and behavior

- Create reusable `WeatherAdvisorPreferences` and `WeatherWeightSlider` components following project conventions.
- Display five labeled sliders with noUiSlider, percentage labels and numeric inputs; load defaults while awaiting user preferences.
- Use **proportional redistribution** of the four other weights when one slider changes. Allocate integer remainder deterministically (largest remainder, fixed factor tie-break order) so sum stays 100. When remaining weights are all zero, distribute remaining percentage evenly in a deterministic order. At a selected weight of 100, all others become zero. Allow users to restore weights from this state.
- Avoid slider feedback loops and stale state; initialize once, update via API when props change, and destroy on unmount (React Strict Mode). Debounce or avoid server calls while dragging; persist only on Save.
- Show total 100%, customized/default status, reset confirmation if unsaved changes, loading, network failure and success feedback.
- Explanation can use an accordion/details area, but essential formula and warning disclaimer should be readily accessible.
- Use responsive Bootstrap/project styling and keyboard accessible numeric controls; avoid color-only distinctions.
- `WeatherWidget.tsx`: near the existing score display (user notes line 166), add authenticated-only React Router link to `/account#weather-advisor-preferences`. Use the **existing** auth hook/context, not a new role gate. Do not show link to guests.
- On `/account`, handle hash navigation after auth/account data loading and lazy rendering. Prefer a router location effect with `requestAnimationFrame`/ref when section is mounted; use `scroll-margin-top` for fixed header and focus the heading when appropriate. Support direct reload with the hash and browser back/forward.
- After save/reset, invalidate/recompute personalized weather assessment queries; do not refetch weather-provider data unnecessarily. If the widget is on another route, ensure it uses fresh effective preferences on navigation.
- Optional: score preview comparing defaults versus saved/draft weights. If included, compute with backend/shared source of truth, not a duplicated TS threshold engine; avoid expanding scope if no suitable preview endpoint exists.

## 7. Phase-by-phase execution with AI prompts

### Phase 0 — Audit and baseline (both repositories)

**Status:** Complete — see [Phase-0-Audit-And-Baseline.md](Phase-0-Audit-And-Baseline.md).

**Tasks:** Find `/account` route/page, `WeatherWidget.tsx`, auth context, API client, weather fetch/assessment route, existing caching, current `Account` model, tests, migrations and use of `WEIGHTS`. Record exact paths and current behavior. Identify whether scoring occurs for guest and authenticated requests. Capture baseline tests.

**AI prompt:**
> Audit both BeachVolleyballHub repositories before editing. Inspect `app/services/weather/volleyball_advisor.rb`, all callers of `Weather::VolleyballAdvisor.assess`, weather endpoints and serializers, `Account` associations, auth and authorization, and frontend `/account`, `WeatherWidget.tsx` around line 166, routing, weather query hooks and test setup. Produce a file-path-specific dependency map, current response shapes, caching risks, and proposed minimal changes. Do not modify code. Flag anything that conflicts with this plan.

**Exit:** Actual file map and test baseline documented.

### Phase 1 — Persistence and model (API)

**Status:** Complete — see [Phase-1-Persistence-And-Model.md](Phase-1-Persistence-And-Model.md).

**Tasks:** Generate migration/model, association, unique FK, check constraints and model tests. Confirm account deletion conventions.

**AI prompt:**
> Implement a one-to-one `WeatherAdvisorPreference` owned by `Account`, with five integer weight columns, defaults 40/20/25/5/10, range 0..100, exact sum 100, DB checks, unique account FK and model validations. Use current Rails conventions and account deletion policy. Do not backfill or change weather behavior yet. Add RSpec coverage for defaults, invalid sums, boundaries, isolation and deletion. Run focused tests and report commands/results.

**Exit:** Migration reversible; validation enforced in DB and Rails.

### Phase 2 — Parameterize scoring (API)

**Tasks:** Keep default constant backward compatible; accept optional validated weights; preserve existing factor functions, labels, advice and warnings. Handle zero total measured weight gracefully. Add optional breakdown if useful and backward compatible.

**AI prompt:**
> Refactor `Weather::VolleyballAdvisor` to accept optional effective weights while preserving default results and existing `.assess` callers. Keep original factor scoring thresholds and warning/safety override behavior unchanged. Validate supplied weights at a clear boundary; use normalized fractions or percentage values consistently. Exclude missing measurements and zero-weight factors, and return Unknown when no positive weighted measurements remain. Add RSpec cases for defaults, custom weights, all-zero available weights, missing measurements, extreme weather warnings and rounding. Avoid unrelated refactoring.

**Exit:** Existing fixtures remain unchanged under defaults.

### Phase 3 — Authenticated preferences API (API)

**Tasks:** Add GET/PUT/DELETE using current route namespace, current-account lookup, strong params, atomic update, consistent error response and request specs.

**AI prompt:**
> Implement authenticated, current-account-only weather advisor preference GET, PUT and DELETE endpoints using the repository's routing, controller and serializer patterns. GET returns effective weights, defaults and customized flag; PUT validates and atomically persists all five weights; DELETE resets by deleting override. Never accept client-supplied account IDs. Add request specs for guest rejection, each authenticated role, cross-account isolation, validation errors, idempotent reset and concurrent creation. Document actual routes and payloads.

**Exit:** No IDOR or unauthorized writes.

### Phase 4 — Personalized weather integration (API + frontend data layer)

**Tasks:** Trace and update weather assessment call sites. Keep provider data cache shareable, personalized score private. Add frontend API functions/types/query keys and invalidation.

**AI prompt:**
> Integrate the account's effective weather weights into the existing weather assessment flow. Preserve guest defaults and all warnings. Audit caching so user-specific scores are never returned to another user; prefer caching raw weather and calculating suitability per request. Extend frontend weather types and API hooks using existing conventions. Ensure save/reset invalidates personalized assessments without unnecessary provider refetch. Add integration tests for two users with different weights and one guest at identical weather inputs.

**Exit:** User A/B/guest can receive distinct suitability scores, with identical raw weather and warnings.

### Phase 5 — noUiSlider component (frontend)

**Tasks:** Install dependency, import stylesheet, build reusable controlled slider + numeric input, implement deterministic rebalance, test keyboard and Strict Mode lifecycle.

**Commands:**
```bash
cd beachvolleyballhub_frontend
npm install nouislider
npm run build
```

**AI prompt:**
> Add `nouislider` to the React/TypeScript frontend. Create an accessible `WeatherWeightSlider` wrapper that initializes once per mount, destroys on cleanup, handles controlled value changes without loops and supports keyboard/numeric input. Build a pure `rebalanceWeatherWeights` utility that keeps five integer weights within 0..100 and summing exactly 100, redistributing other weights proportionally with deterministic largest-remainder rounding and an all-others-zero fallback. Add tests for 0%, 100%, repeated edits, rounding, Strict Mode remounts and keyboard interaction. Follow existing styling.

**Exit:** Slider is stable, accessible and total always 100.

### Phase 6 — `/account` explanation and editor (frontend)

**Tasks:** Add bottom-of-page anchored section, fetch effective weights, explanatory copy with exact Ruby scoring rules, save/reset/discard states, optional comparison preview.

**AI prompt:**
> Add `WeatherAdvisorPreferences` at the end of the existing `/account` page, `id="weather-advisor-preferences"`. Explain exactly how the five Ruby factor scores, missing-data normalization, labels and independent warnings work; make clear it is not a certified safety assessment. Show five noUiSlider controls and percentages, total 100, Save, Discard and Reset to Defaults. Use current account API/auth patterns; handle loading, 401, 422, network errors and unsaved changes. Keep all authenticated roles eligible. Make section responsive and accessible. Test API states and actions.

**Exit:** Account owners can understand, edit and reset preferences.

### Phase 7 — WeatherWidget link and deep linking (frontend)

**Tasks:** Add authenticated-only link near existing score (approximately line 166). Hash navigation, scrolling after async render, header offset and reload support.

**AI prompt:**
> Inspect `WeatherWidget.tsx` around line 166 and the project's authentication context. Add a visible `Configure Weather Preferences` link for **every authenticated user**, with no role or organization restriction; hide it for guests. Navigate with React Router to `/account#weather-advisor-preferences`. Ensure `/account` scrolls reliably to the newly rendered section after asynchronous loading, handles direct hash URL reload and browser history, and applies fixed-header scroll offset. Add component/router tests for logged-in users and guests.

**Exit:** Link works for player, coach, curator, admin and any other authenticated role.

### Phase 8 — End-to-end tests, regression and security

**Tasks:** Verify guest defaults, account isolation, preference persistence across sessions, weather recomputation, warnings independent of weights, direct hash navigation, mobile UI, accessibility, query cache isolation, 401/422 handling. Run API tests, lint, TypeScript build, UI tests and E2E suite using existing tools.

**AI prompt:**
> Perform a full regression/security audit of the Weather Advisor Preferences feature across both repositories. Run existing RSpec, lint/typecheck/build, frontend unit tests and Playwright E2E where available. Cover account isolation, missing weather factors, zero weights, custom score computation, warnings, authenticated-only widget link, hash scrolling, reset and cross-user cache leakage. Report failing tests with exact commands and fix only relevant issues. Produce a test matrix and summary of changed files.

**Exit:** Green tests; no guest or cross-account leakage; no regression in default weather scoring.

### Phase 9 — Release and rollout

**Tasks:** Deploy migration first, then compatible backend, then frontend. Confirm API CORS/session auth, production environment and existing Cloudflare/Render deployment conventions. Smoke-test guest and two accounts. Monitor errors with existing observability; document rollback.

**AI prompt:**
> Prepare a release checklist for this feature on the project's current Cloudflare frontend, Render Rails API and PostgreSQL infrastructure. Confirm migration compatibility and deployment order, auth/CORS, rollback strategy, smoke tests for guest/two accounts, and Sentry monitoring. Do not add new paid infrastructure or secrets. Produce concise release notes and any remaining risks.

**Exit:** Feature working in production with rollback path.

## 8. Suggested test matrix

| Scenario | Expected |
|---|---|
| No saved preferences | Defaults 40/20/25/5/10 |
| Save 35/25/25/5/10 | Persist and use custom scoring |
| Sum 99 or 101 | 422 and no partial update |
| Weight -1, 101, decimal, missing key | 422 |
| One factor 100; others 0 | Valid; score uses only selected factor if available |
| Selected factor missing and others zero | Unknown, no division by zero |
| All weather measurements missing | Unknown |
| Dangerous wind with wind weight 0 | Wind warning still displayed |
| Two accounts with different preferences | Distinct results; no data leakage |
| Guest weather | Default weights; no settings link |
| Logged-in user with any role | Settings link visible |
| Open `/account#weather-advisor-preferences` directly | Correct section scrolled into view |
| Reset | Overrides deleted; default scoring restored |
| React Strict Mode | One functional slider per control; cleanup correct |

## 9. Definition of done

- [ ] Account-owned persisted preferences and DB constraints
- [ ] Backward-compatible parameterized advisor
- [ ] Account-scoped authenticated preference endpoints
- [ ] Per-account weather assessment and cache isolation
- [ ] noUiSlider controls and exact 100% rebalance
- [ ] Scoring explanation at bottom of `/account`
- [ ] `/account#weather-advisor-preferences` deep link
- [ ] Authenticated-only link in `WeatherWidget.tsx` near score
- [ ] Independent warnings preserved
- [ ] API/frontend/E2E tests and production smoke tests

## 10. Notes for implementer

Do not assume paths or conventions not confirmed in Phase 0. Keep weather factor **scoring thresholds** separate from customizable **weights**. No new API key is needed for this feature. The only new UI dependency proposed is `nouislider`; reuse existing backend libraries, auth and test tooling wherever possible.
