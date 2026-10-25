# Phase 0 — Repository Audit and Decisions

**Completed:** 24 October 2026

## Findings

- Backend is Rails 8.1 with PostgreSQL and Minitest; frontend is React/TypeScript/Vite.
- Actual models are `Organisation`, `Group`, `TrainingSession` and `Tournament`.
- `TrainingSession` already owns a legacy `location` string. The canonical association therefore uses `canonical_location`, backed by `location_id`, so existing serialization and forms remain compatible.
- `Tournament` already stores `location_name`, city, state and country.
- Existing authorization primitives are `Current.user`, role predicates, `OrganisationAccess`, and content-management concerns.
- No approved Google Maps key, Places API contract, geocoder job framework or vetted Sydney coordinate source was present.

## Approved changes to the proposed plan

1. Keep legacy free-text fields during the additive migration.
2. Implement `OrganisationLocation` now because issue #213 requires an organisation to use multiple venues.
3. Limit V1 events to one optional Court each. Multi-court tournament allocation is deferred.
4. Use provider-free Google Maps directions URLs instead of embedding Maps JavaScript or collecting a key.
5. Do not import or guess venue coordinates without reviewed provenance.
6. Add a report-only backfill task before any data mutation.

## Repository locations

- Backend: `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api`
- Frontend: `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub`