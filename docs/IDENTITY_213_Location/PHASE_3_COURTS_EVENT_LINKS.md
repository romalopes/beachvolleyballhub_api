# Phase 3 — Courts and Event Links

**Completed:** 24 October 2026

## Delivered

- Structured `courts` child table with name, optional coordinates, access instructions and lifecycle status.
- Nullable location and court links on Training Sessions and Tournaments.
- `Tournament.location_detail` for one-off meeting/access instructions.
- Validation that a selected Court belongs to the selected Location.
- Validation that newly selected Locations are active and verified.
- Default-location snapshots are assigned only when creating an event; later default changes do not move existing events.

## Compatibility decision

`TrainingSession.location` remains the historical display/free-text field. Its canonical association is `canonical_location`; this avoids overriding the existing Active Record attribute method.

## Deliberate V1 limit

Each Training Session and Tournament supports one optional Court. Tournament multi-court joins and match-level allocation remain out of scope.