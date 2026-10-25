# Phase 8 — Training and Tournament Frontend

**Completed:** 24 October 2026

## Delivered

- Shared TypeScript `Location` and `Court` contracts and API client methods.
- Training form verified-venue selector, dependent Court selector and retained free-text location field.
- Tournament form verified-venue selector, dependent Court selector, venue label and meeting/access detail.
- Existing edit forms load persisted canonical selections.
- Event save payloads include `location_id`, `court_id` and compatibility text fields.
- Training and Tournament detail pages render canonical venue, Court and access details.
- Shared inline venue-proposal form for Training and Tournament creation/editing.
- A created proposal is inserted into the local selector and selected immediately,
  its compatibility venue label is copied, and any stale Court selection is cleared.
- Pending proposals remain selectable by their proposer while verified active
  locations remain selectable by everyone; another account cannot link the proposal.
- The UI explains that coordinates resolve asynchronously and verification is pending.
- Proposal fields include name, type, address, locality, administrative area,
  country code and timezone. Ordinary users never submit coordinates.

## Resilience

Forms continue working if location catalogue loading fails: canonical selection becomes unavailable, but historical/free-text location editing remains usable.

## Validation

- Focused location API/component/event-form Vitest: 4 files, 81 tests passed.
- Full frontend Vitest: 103 files, 1,011 tests passed.
- Production TypeScript/Vite build passed after the proposal integration.