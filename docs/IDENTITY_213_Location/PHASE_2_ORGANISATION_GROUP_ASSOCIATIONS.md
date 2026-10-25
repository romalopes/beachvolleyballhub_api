# Phase 2 — Organisation and Group Associations

**Completed:** 24 October 2026

## Delivered

- `organisation_locations` many-to-many association with optional notes.
- Nullable `Organisation.default_location_id` and `Group.default_location_id`.
- Validation that defaults are verified, active and associated with the organisation when applicable.
- Effective Group default resolution: Group override, then Organisation default.
- Default location metadata in Organisation and Group API payloads.
- `LocationDefaultResolver` for new event prefilling without materializing inherited values.

## Authorization

- Organisation venue association writes reuse `OrganisationAccess.can_edit?`.
- Canonical location editing remains separate from organisation association management.

## Deferred UI

Dedicated Organisation and Group location-management panels remain Phase 7 follow-up work. The backend endpoints and metadata are ready for that UI.