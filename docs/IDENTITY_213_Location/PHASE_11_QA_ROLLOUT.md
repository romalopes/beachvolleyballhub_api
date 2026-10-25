# Phase 11 — QA and Rollout Status

**Local QA completed:** 25 October 2026

## Passing validation

### Organisation location management and event prefill — 25 October 2026

- Focused Rails location suite (models, relationships, event assignment, geocoding
  job and provider, locations API, organisation-locations API): **38 runs, 113
  assertions, 0 failures, 0 errors**.
- New request coverage for the organisation venue endpoints: attach, detach by
  association id, the refusal to detach the current default, the refusal of a
  default that is not one of the organisation's own venues, and the refusal of
  an unverified venue.
- Frontend location suite (new `OrganisationLocations` component, Organisation
  detail page, Tournament form, Training form): **3 files, 43 tests passed**.
- Full frontend suite: **104 files, 1,027 tests passed**.
- Frontend production TypeScript/Vite build passed.
- Full frontend ESLint: **0 errors**. The three remaining
  `react-hooks/exhaustive-deps` warnings are the pre-existing ones in the
  large Tournament/Training form components and the settings Locations list.
- Targeted RuboCop over the Location files: **19 files, no offenses**.

### Geocoding and proposal increment — 24 October 2026

- Focused Rails geocoding/location suite: **25 runs, 84 assertions, 0 failures, 0 errors**.
- Affected Tournament/Training model, service and request suite: **128 runs,
  478 assertions, 0 failures, 0 errors, 1 existing skip**.
- Focused frontend location API/component/event-form suite: **4 files, 81 tests passed**.
- Full frontend suite: **103 files, 1,011 tests passed**.
- Frontend production TypeScript/Vite build passed.
- Targeted frontend ESLint completed with no errors; two existing hook dependency
  warnings remain in the large Tournament/Training form components.

- Database migration applied to development and test PostgreSQL databases.
- Focused Rails suite: **90 runs, 315 assertions, 0 failures, 0 errors**.
- Targeted RuboCop: **14 files, no offenses**.
- Frontend Vitest: **102 files, 1,005 tests passed**.
- Frontend production build passed.
- Backend and frontend `git diff --check` passed.

## Full backend suite disclosure

The full Rails suite was rerun after this increment: **1,488 runs, 5,984
assertions, 14 failures, 4 errors, 1 skip**. The issue-specific geocoding,
Location, Tournament and Training suites pass. Remaining failures are in
pre-existing organisation/group membership expectations, environment-dependent
health/email tests and time-sensitive tournament participation/division tests;
they are outside the Location implementation and were not masked.

## Build warnings

The frontend build retains existing warnings about an unavailable Sentry export and a large output chunk. They do not fail the build and are unrelated to issue #213.

## Pending release work

- Apply migration to a staging backup and smoke-test API/forms.
- Run and reconcile `locations:backfill_report`.
- Approve a coordinate provenance dataset before any Sydney seed import.
- Create/restrict the production Geoapify key and confirm billing/quota alerts.
- Set the identifying production `GEOCODING_USER_AGENT` on web and worker services.
- Smoke-test Solid Queue retries, provider failures and coordinate resolution on staging.
- Add the Group override/inheritance selector with an explicit "uses the
  organisation default" state.
- Complete production smoke tests and rollback rehearsal.