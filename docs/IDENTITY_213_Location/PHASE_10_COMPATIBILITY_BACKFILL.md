# Phase 10 — Compatibility and Backfill

**Completed locally:** 24 October 2026

## Delivered

- All canonical foreign keys are nullable.
- Legacy Training and Tournament location fields remain readable and writable.
- New event creation can snapshot a Group/Organisation default Location.
- Existing event records are not retroactively changed when defaults change.
- `bin/rails locations:backfill_report` reports unmatched legacy Training and Tournament values without mutating data.

## Production procedure still required

1. Run the report against a production backup or staging clone.
2. Review exact and alias candidates manually.
3. Apply only high-confidence mappings through a separately reviewed task.
4. Keep ambiguous rows on legacy text until curated.
5. Do not remove compatibility fields in the same release.