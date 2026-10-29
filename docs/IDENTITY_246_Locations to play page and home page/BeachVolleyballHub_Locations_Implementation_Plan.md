# Beach Volleyball Hub — Locations, Organisations & Places to Play
**Implementation plan and AI coding prompts**  
**Date:** 29 October 2026  
**Status:** Proposed; validate against current repository before coding.

## 1. Goals and established findings

Build a coherent location experience for public visitors, authenticated players, coaches, organisation managers, curators, and admins.

**Existing behaviour reported by the project owner (preserve):**
- Normal users propose locations; Admin/Curator creates, verifies or rejects.
- Public `/` and `Home.tsx` maintain one effective map target from browser geolocation, IP fallback, Coogee fallback, or coordinates from weather/geocoding after a submitted Google Maps search.
- Active organisations have a canonical `default_location`.
- Existing organisations index is authenticated and intended for management/tree views; do **not** expose it publicly.
- Backend `GeoRadius` already validates and filters geographic radius searches for training sessions and tournaments.
- For Home, show **one active organisation at its verified default location**, not every attached venue.
- Home's existing local-event radius convention is 25 km.
- Organisation detail pages may remain authenticated.

**Verification boundary:** These findings are supplied by the project owner; they have not been independently confirmed by a fresh repository inspection. Before implementing, inspect the actual files, routes, schemas, tests and permissions. Reuse existing names/structures rather than blindly introducing duplicates.

## 2. Product decisions

### 2.1 Location catalogue
- `/locations`: public searchable list and map of **active, verified** locations only.
- `/locations/:slug` (or existing route convention): public details of an approved location, including address, coordinates, facilities, photos (if supported), associated public organisations, and public upcoming training/tournaments.
- Normal user: propose a location; see **own** pending/rejected submissions and rejection reason; optionally revise/resubmit according to current moderation rules.
- Admin/Curator: review, approve, reject, archive and resolve duplicates.
- Keep `approval_status` distinct from public visibility/active state if existing schema supports it. Never expose internal moderation fields publicly.
- Public list should support text, locality, country/state, and nearby-radius filters. Add facility/court filters only if the data is reliable.

### 2.2 Organisations and locations
- Reuse canonical `Organisation.default_location` for **Home nearby organisations**.
- For the organisation detail page, show primary location map immediately and a Locations tab/section for additional venues if such associations exist.
- If multiple locations per organisation are not already supported, add a join relationship only after auditing existing organisation/location models and migrations.
- One organisation can use multiple approved locations; a location can be used by many organisations. Enforce at most one primary association if a join model is introduced.
- Organisation managers may associate existing verified locations if authorised; they cannot approve unverified locations.
- Avoid automatically inheriting parent organisation venues; optionally offer parent locations as suggestions.
- Keep private organisation details behind existing auth; public Home links to protected pages should lead to a sensible sign-in flow, not broken navigation.

### 2.3 Public Home — Places to play
- Show responsive cards beneath Home's existing map/location panel, before agenda/hourly content.
- Use **the same effective coordinates as the map**. Do not derive a second independent location.
- Display one active organisation with one active, verified, coordinate-bearing `default_location`.
- Show name/logo fallback, organisation type, venue, locality/address, distance km, and organisation link.
- Fetch with a fixed **25 km** initial radius, configurable later.
- When submitted search coordinates are resolved through existing weather/geocoding, refresh the list; do not show old-position results for the new search.
- Preserve `Use my location` and browser/IP/Coogee fallbacks.
- Include loading, empty, error, and retry states; cancel/ignore stale requests.

### 2.4 Google Maps integration
- Reuse existing Google Maps integration and API key strategy; first inspect whether project uses Embed, Maps JavaScript API or a wrapper.
- A reusable map component should support: one location, multiple markers, selected marker, fit bounds, info window, accessible list fallback and Directions link.
- Organisation overview: show primary default-location map.
- Organisation Locations tab: show all approved, public associated venues and a matching list.
- Public catalogue: map and list use the same filtered results; avoid overlapping markers with clustering when needed.
- Training/tournament details: reuse the same location map if applicable.
- Do not add Maps JS or Places API solely for a static one-marker view if the existing Embed integration is adequate; interactive catalogue may warrant Maps JS.
- Restrict browser API keys by HTTPS referrer and API; review quotas, billing, privacy, and geolocation consent. Never expose a server-side secret key in `VITE_*`.

## 3. Proposed API contracts (adapt to existing conventions)

### Public nearby organisations
`GET /api/v1/organisations/nearby?latitude=-33.92&longitude=151.26&radius_km=25&limit=20`

Example response (illustrative; follow existing serializer/envelope conventions):
```json
{
  "organisations": [
    {
      "id": 123,
      "name": "Example Volleyball Club",
      "organisation_type": "club",
      "logo_url": null,
      "default_location": {
        "id": 456,
        "name": "Example Beach",
        "latitude": -33.92,
        "longitude": 151.26,
        "formatted_address": "Sydney NSW"
      },
      "distance_km": 2.4
    }
  ]
}
```

**Rules:**
- Public read-only route distinct from authenticated organisations management index.
- Required latitude/longitude; optional `radius_km` and `limit`; strict numeric validation; reject partial/malformed/nonfinite/out-of-range coordinates with 422/400 per API convention.
- Reuse `GeoRadius` bounds/haversine SQL; bind values safely; cap radius and result limit; deterministic order by distance then ID.
- Filter organisation active, `default_location` present, active, verified, coordinates present.
- Deduplicate by organisation ID; do not fan out through all venue associations.
- Only public fields; omit moderation details, internal flags and sensitive data.
- Anonymous authorisation must not leak privileged capabilities.
- Add suitable indexes only after inspecting query plans and existing indexes.

### Other APIs — inspect before adding
- `GET /api/v1/locations` for approved public locations.
- `GET /api/v1/locations/:id` or slug details.
- `GET /api/v1/locations/mine` for the user's proposals.
- Existing moderation endpoints for approve/reject.
- `GET /api/v1/organisations/:id/locations` for publicly displayable venues.
- Permission-gated attach/detach/update-primary organisation-location endpoints.
- Public organisation summary route only if truly needed; do not relax existing management endpoints.

## 4. Suggested data modelling

Inspect `Location`, `Organisation`, default location foreign key, approval state, `TrainingSession`, `Tournament`, associations, indexes, and policies first.

**Only if missing:** introduce `OrganisationLocation` with:
- `organisation_id`, `location_id`, `is_primary` (or reuse canonical default_location), `usage_type`, `notes`, timestamps.
- unique `(organisation_id, location_id)`;
- foreign keys and indexes;
- partial unique index on primary per organisation, **only if** this doesn't conflict with the canonical default-location relationship.
- Decide on one authoritative primary source; **do not** let join `is_primary` and `Organisation.default_location` drift. Prefer retaining `default_location` as source of truth and omit redundant `is_primary` unless there is a compelling reason.

**Later:** `LocationCourt` or `LocationArea` for numbered courts, rather than multiple duplicate map pins; correction requests and review history if absent.

## 5. Permissions and privacy matrix

| Action | Visitor | Signed-in user | Organisation manager | Admin/Curator |
|---|---|---|---|---|
| View verified active locations | Yes | Yes | Yes | Yes |
| View public nearby organisations | Yes | Yes | Yes | Yes |
| Propose location | No | Yes | Yes | Yes |
| View own proposals | No | Yes | Yes | Yes |
| View others' pending proposals | No | No | No | Yes |
| Approve/reject location | No | No | No | Yes |
| Attach verified location to managed organisation | No | No | Yes | Yes |
| Edit location globally | No | No | No | Yes, per existing rules |

Check actual curator scope and tenant boundaries; don't assume all curators are global. Public pages must not reveal pending/rejected/archived location coordinates, internal notes or sensitive organisation metadata.

## 6. Phased delivery and AI prompts

Each prompt assumes an AI coding assistant working with both repositories. Execute one phase at a time; inspect changes, run tests, commit after review.

### Phase 0 — Repository audit and architecture decision
**Deliverables:** existing model/route/component inventory; gap analysis; approved API and permission design; no code changes.

**AI prompt**
> Inspect `romalopes/beachvolleyballhub_api` and `romalopes/beachvolleyballhub_frontend` (or the current local checkout). Identify Location and Organisation models, `default_location`, active/verified scopes, approval flow, organisation associations, `GeoRadius`, route/controller/serializer contracts, Home's resolved effective coordinates and Google Maps integration, API client, tests, and role policies. Confirm or correct the findings in this plan with file:line evidence. Propose minimal changes and flag migration/backward-compatibility risks. Do not modify code yet.

### Phase 1 — Public nearby-organisations backend
**Deliverables:** public endpoint, query/service, safe serializer, tests.

**AI prompt**
> Implement a new public read-only nearby-organisations endpoint in Rails without changing authentication on the existing organisations index. Accept latitude, longitude, optional radius_km (default 25) and capped limit. Reuse the existing `GeoRadius` validation and bounding-box/haversine SQL used by training sessions/tournaments. Return each active organisation once using its canonical default_location only when that location is active, verified and geocoded. Sort nearest first with deterministic ties; include distance_km and safe public organisation/default-location fields. Preserve existing API conventions and authorisation. Add focused controller/query tests for anonymous access, ordering, radius, invalid/partial coordinates, excluded statuses, missing default location, deduplication, cap and no internal-field leakage. Avoid N+1 queries.

### Phase 2 — Typed frontend API and request lifecycle
**Deliverables:** types, API method, exact path test, cancellation support.

**AI prompt**
> Inspect the existing `src/api.ts` and API base URL conventions. Add typed nearby-organisation response and a single API method building the exact `/api/v1/organisations/nearby` request without duplicating `/api/v1`. Accept latitude, longitude, radius_km, limit and optional AbortSignal. Use existing fetch/error conventions. Add `src/api.test.ts` tests for exact path, encoding, response shape and signal forwarding. Avoid new dependencies.

### Phase 3 — Home Places to Play component
**Deliverables:** reusable responsive list/card component and unit tests.

**AI prompt**
> Create a reusable `src/components/home/PlacesToPlay.tsx` (or existing convention) for public nearby organisations. Show logo/fallback, name, type, canonical default venue, locality/address, distance_km and an accessible organisation link. Implement loading, empty, error/retry and populated states. Ensure signed-out users can see cards even if organisation detail navigation requires login. Follow current styles and accessibility patterns. Add component tests for all states, long names, missing logos and links.

### Phase 4 — Home effective-coordinate integration
**Deliverables:** location-synchronised list beneath map and race tests.

**AI prompt**
> Inspect `Home.tsx` and identify its one authoritative effective map coordinate state. Mount PlacesToPlay directly below the map/location panel and before agenda/hourly content. Request nearby organisations at 25 km whenever those coordinates change. Support browser geolocation, IP fallback, Coogee fallback, submitted search coordinates only after existing weather/geocoding resolution, and Use my location. Abort prior requests on coordinate changes/unmount; ensure late responses cannot overwrite current results. Preserve weather/map behaviour. Add Home tests for initial coordinates, search refresh, restore current location, stale response and errors.

### Phase 5 — Public Locations catalogue and details
**Deliverables:** public routes, search/list/map, detail page, tests.

**AI prompt**
> Reuse the existing Location APIs and models to implement a public `/locations` page showing only active verified locations in a searchable list plus map. Support name, state/city and optional nearby filters using existing backend query utilities. Implement location details with address, coordinates, supported facilities and public linked activities/organisations. Do not expose pending, rejected, archived or internal moderation fields. Preserve current admin/curator workflows. Add backend visibility/filter tests and frontend list/detail tests. Avoid duplicate APIs and map implementations.

### Phase 6 — My Location Suggestions
**Deliverables:** user's proposal list/status/rejection feedback and tests.

**AI prompt**
> Extend the existing location proposal workflow with a My Suggestions view showing the signed-in user's pending, approved and rejected proposals and safe rejection reasons. Use existing routes if possible. Allow resubmission only if supported by the moderation model; otherwise specify a minimal safe workflow. Enforce creator-only access on the backend and prevent other users' proposals from being enumerated. Test visibility and permissions.

### Phase 7 — Organisation ↔ Locations data and APIs
**Deliverables:** associations only if missing, management APIs, policies and migrations/tests.

**AI prompt**
> Inspect existing Organisation default_location and venue associations before changing schema. Preserve default_location as the canonical primary location. If multi-location support is absent, implement a many-to-many OrganisationLocation relationship with unique pairs, foreign keys and appropriate indexes, without duplicating primary state. Allow authorised organisation managers to attach/detach only verified active locations and set the canonical default location. Respect hierarchy/tenant and curator permissions; prevent approval bypass. Add model, controller, policy and migration tests; document rollback/backfill.

### Phase 8 — Reusable map and organisation pages
**Deliverables:** shared map component; organisation overview and Locations tab.

**AI prompt**
> Audit the current Google Maps implementation, keys and billing assumptions. Extract or extend a reusable React map component supporting one marker, many markers, selected location, fit bounds, accessible list fallback and Directions links. On organisation overview, show the canonical default location; in Locations tab show all associated verified active locations. Reuse current API/permissions and avoid rendering protected details publicly. Prefer existing libraries; introduce Maps JavaScript API only where interactive features require it. Add tests for one/no/multiple locations and protected routes.

### Phase 9 — UX, corrections and duplicates
**Deliverables:** duplicate warning, correction requests and court-level roadmap.

**AI prompt**
> Before a user submits a new location, search existing active verified venues within an appropriate configurable radius (initial suggestion 150 m), and suggest matching names/addresses. Allow the user to continue only under existing moderation rules. Design an approval-gated Suggest Correction workflow for inaccurate approved locations. Do not silently edit verified coordinates. Assess whether numbered courts should be LocationArea/LocationCourt children instead of separate locations. Add permission and proximity edge-case tests.

### Phase 10 — Quality, observability, rollout
**Deliverables:** test evidence, deployment checklist, performance checks and rollback.

**AI prompt**
> Run focused Rails location/organisation/GeoRadius tests, frontend API/component/Home tests, frontend lint/full test suite/production build, and `git diff --check`. Run backend full suite if feasible and report pre-existing failures separately. Check anonymous vs authenticated behaviour, geolocation-denied fallback, mobile responsiveness, map billing/quota, CORS, performance and N+1 queries. Confirm only approved active locations leak through public APIs. Produce a concise release checklist, migrations/backfill plan, smoke tests, feature-flag or staged rollout strategy, and rollback steps. Do not claim success for commands not executed.

## 7. Regression test checklist

### Rails
- Anonymous nearby-organisations request succeeds.
- Nearest-first order, deterministic ties and correct `distance_km`.
- Radius exclusion and boundary behaviour.
- Inactive organisation excluded.
- Missing, pending, rejected, archived, inactive or ungeocoded default location excluded.
- Duplicate venue associations do not duplicate organisation rows.
- Missing/partial, nonnumeric, NaN, infinite, out-of-range coordinates rejected.
- Excessive radius/limit constrained.
- Safe public serializer excludes internal moderation and privileged flags.
- No accidental public access to management organisations index.
- Organisation-location attach/detach permissions and cross-tenant restrictions.
- Proposal creator can view own status; others cannot.

### Frontend
- API path contains exactly one `/api/v1`, correct query params, forwarded signal.
- Places to Play loading/error/empty/populated/retry states.
- Logo fallback, venue, distance, organisation links.
- Initial detected coordinates, IP fallback, Coogee fallback.
- Search coordinates update **after** geocoding/weather resolution.
- Use my location restores correct results.
- Abort and ignore stale requests; unmount cleanup.
- Public Home works signed out; protected organisation links handle login.
- Map/list responsive and accessible; missing coordinates handled.

## 8. Expected files to inspect or modify

**Backend checkout:** `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api/`
- `config/routes.rb`
- `app/controllers/api/v1/organisations_controller.rb`
- `app/models/organisation.rb`
- Existing `GeoRadius` service and location models/controllers/serializers/policies (locate actual paths).
- `test/controllers/api/v1/organisations_controller_test.rb`
- Existing GeoRadius, location and organisation tests.
- New migration/model/policy/tests **only if** organisation-location relationship is missing.

**Frontend checkout:** `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub/`
- `src/api.ts`
- `src/api.test.ts`
- `src/pages/Home.tsx`
- `src/pages/Home.test.tsx`
- `src/components/home/PlacesToPlay.tsx` and its test (new)
- `src/App.css`
- Existing organisation pages, location pages, map components, router and related tests (inspect exact paths).

**Repository naming note:** current public GitHub frontend repository is `romalopes/beachvolleyballhub_frontend`; local folder is reported as `beachvolleyballhub`.

## 9. Execution commands (adapt to actual scripts)

Backend:
```bash
cd /Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api
bin/rails routes | grep -E 'organisation|location'
bin/rails test test/controllers/api/v1/organisations_controller_test.rb
# After adding new tests, run focused location/model/service suites.
bin/rails test
git diff --check
```

Frontend:
```bash
cd /Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub
cat package.json
# Use package.json's actual test/lint/build scripts:
npm test -- --run
npm run lint
npm run build
git diff --check
```
Do not assume npm vs pnpm; use the repository lockfile and scripts.

## 10. Release order and acceptance criteria

**Release A — Home discovery (Phases 0–4):** Anonymous Home visitors see correct nearby active organisations at verified default venues, centred on the effective map coordinates, with 25 km radius and no stale search results.

**Release B — Public Locations (Phases 5–6):** Users can discover approved locations and track their own proposals; pending/rejected locations remain private.

**Release C — Organisation maps (Phases 7–8):** Organisation pages show their primary Google Maps marker and optionally all associated approved venues; authorised managers maintain associations.

**Release D — Quality of location data (Phases 9–10):** Duplicate warnings, correction workflows, robust tests and staged rollout.

### Non-goals for the first release
- Exposing the authenticated organisations management/tree API to anonymous visitors.
- Displaying every venue as a separate organisation on Home.
- Automatically approving location proposals.
- Replacing the existing Home geolocation/weather pipeline.
- Adding new paid mapping/geocoding services without a usage/cost decision.
- Building full court booking/reservation management.

## 11. Open decisions to resolve during Phase 0
1. Is the organisation's `default_location` a foreign key, method, or derived association?
2. Is many-to-many organisation-location already implemented?
3. Does the current public location API exist, and which status fields represent verified/active?
4. Which map implementation is in use and what are its enabled Google APIs?
5. Can unauthenticated visitors open organisation details, or should cards explicitly show sign-in requirements?
6. Is curator authority global or organisation-scoped?
7. Should the public location details show all associated organisations or only those whose default venue matches?

**Recommendation:** Start with Release A, because it builds directly on existing `GeoRadius`, `default_location`, and Home's resolved coordinates with minimal schema change.
