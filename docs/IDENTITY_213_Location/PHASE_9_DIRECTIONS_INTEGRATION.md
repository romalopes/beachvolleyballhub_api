# Phase 9 — Directions Integration

**Completed:** 24 October 2026

## Implemented scope

Locations with coordinates expose a Google Maps directions/search URL. Training and Tournament detail pages render this as an accessible external link alongside the saved text address, Court and meeting details.

## Why the original embedded-map scope changed

The repositories contain no approved Maps JavaScript/Places key, quota, billing policy or environment contract. Adding an embedded map would introduce an operational dependency and secret configuration not approved by issue #213. Provider-free links deliver useful directions without blocking page rendering or requiring a key.

## Deferred

- Embedded Maps JavaScript components.
- Places autocomplete and Place ID storage.
- Browser geolocation and distance sorting.
- Map-key restrictions, quotas and billing alerts.