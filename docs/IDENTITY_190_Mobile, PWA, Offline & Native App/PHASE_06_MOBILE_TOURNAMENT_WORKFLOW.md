# Phase 06 — Mobile Tournament Workflow

## Purpose

Support offline tournament operation while keeping official results server-authoritative.

## Requirements

- Download the tournament boundary before travel.
- Support court operation, live scoring, match results and local standings.
- Persist every score/result immediately.
- Define validation before official publication.
- Detect and display conflicts; never silently overwrite tournament results.

## Acceptance criteria

- The current API exposes tournament metadata, participation, divisions and watch links, but no match, score or result resources. There is therefore no existing tournament scoring mutation to wire into the queue.
- A separate tournament scoring API/domain design is required before offline tournament scoring can be implemented safely.
- Backend idempotency is now available for JSON API mutations, but explicit tournament conflict responses remain dependent on that future scoring API.
- Existing online tournament behavior is preserved.