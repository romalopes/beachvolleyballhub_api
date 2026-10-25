# Phase 6 — Location and Court API

**Completed:** 24 October 2026

## Endpoints

- `GET/POST /api/v1/locations`
- `GET/PATCH /api/v1/locations/:id`
- `POST /api/v1/locations/:id/verify`
- `POST /api/v1/locations/:id/archive`
- `GET/POST /api/v1/locations/:location_id/courts`
- `PATCH/DELETE /api/v1/locations/:location_id/courts/:id`
- `GET/POST/DELETE /api/v1/organisations/:organisation_id/locations`

## Permissions

- Any authenticated user may propose a Location.
- Ordinary users can list/select only active verified Locations.
- Curators/admins can inspect proposals, edit canonical data, verify/archive Locations and manage Courts.
- Organisation editors can associate and remove their Organisation's Locations but cannot thereby edit canonical coordinates.

## Response behavior

Location summaries include normalized display/address data, coordinates, lifecycle state and a provider-free map URL. Detail responses include aliases and Courts.

## Tests

Request coverage verifies selection visibility, proposal coordinate stripping and admin verification.