# Phase 5 — Curated Sydney Import

**Status:** Deferred pending provenance approval

## Reason

The repository did not contain a vetted dataset that identifies authoritative venue names, addresses, coordinates, source references and verification dates. Importing search results or guessed coordinates would violate the plan's provenance and safety requirements.

## Readiness delivered

- Canonical Location schema supports source and source-reference fields.
- Normalized names, aliases and scoped uniqueness support idempotent import matching.
- Verification lifecycle can distinguish curated records from user proposals.
- Existing seed execution remains unaffected.

## Required import review

Before implementation, provide a reviewed CSV/JSON source and decide:

1. stable idempotency key;
2. coordinate license and attribution;
3. whether records are inserted as verified or proposed;
4. conflict behavior when a curator has already edited a record;
5. dry-run report and rollback procedure.