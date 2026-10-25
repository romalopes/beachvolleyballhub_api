# Phase 1 — Core Location Domain

**Completed:** 24 October 2026

## Delivered

- Additive migration `20261024000001_create_location_domain.rb`.
- Canonical `locations` table with lifecycle, verification, geocoding, provenance and coordinate fields.
- `location_aliases` for search and deduplication support.
- `Location` and `LocationAlias` models with normalization, bounds, coordinate-pair, merge-target and verification-provenance validations.
- Database check constraints for enum-like states and coordinate ranges.
- Existing development and test databases migrated successfully; `db/schema.rb` updated.

## Safety choices

- No legacy location column was removed or made mandatory.
- Archived or unverified records remain historically readable but are excluded from ordinary selection.
- Exact uniqueness is intentionally scoped by normalized name and locality context; aliases support alternative names without automatically merging records.

## Validation

- Covered by `test/models/location_test.rb` and the focused issue test run recorded in Phase 11.