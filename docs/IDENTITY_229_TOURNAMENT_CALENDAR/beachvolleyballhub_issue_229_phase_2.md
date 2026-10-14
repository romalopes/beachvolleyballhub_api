## 4. Phase 2 — Tournament domain services, lifecycle, timezones

Implement a transaction-backed create/update service accepting tournament details and divisions together; a separate participation service for idempotent self-link, role/division update and unlink; and explicit cancel/archive/restore actions. Capture current time once per request. Temporal status (`upcoming`, `ongoing`, `completed`) is derived; publication state (`active`, `cancelled`, `archived`) is persisted.

Only active, non-completed tournaments accept new participation or role/division changes. Owners can unlink after cancellation/completion, including archived tournaments through a privacy-preserving endpoint. Archive retains records and associations; unused mistakes may be hard-deleted by admins only.

Store UTC instants plus IANA event timezone. For all-day events use exclusive next-day midnight in the event's local timezone, not a fixed 24-hour duration. Reject DST nonexistent wall times; require offset/disambiguation for repeated wall times. No silent conversion from server timezone.

**AI prompt — services**

Implement Tournament mutation, lifecycle and participation services using existing Rails patterns and Phase 1 models. Enforce atomic creation with at least one active division; scheme immutability once linked; no deletion of referenced divisions; safe idempotent Account self-link; server-derived Account identity; lifecycle restrictions; cancellation/archive/restore; DST-safe date normalization. Lock the parent tournament for division and participation mutations, handle unique-index conflicts without 500 errors, and test simultaneous requests. Include audit attribution for effective and real user where existing conventions support it. No API controllers or React changes in this phase.

**Gate:** service tests cover invalid states, concurrency, DST, and archived self-unlink.