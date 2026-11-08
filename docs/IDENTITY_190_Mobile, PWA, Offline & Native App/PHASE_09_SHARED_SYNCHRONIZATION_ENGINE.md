# Phase 09 — Shared Synchronization Engine

## Purpose

Synchronize local operations safely and consistently across Training, Assessment and Tournament workflows.

## Requirements

- Queue operations with client-generated idempotency keys.
- Retry transient failures with bounded backoff.
- Preserve operation order when dependencies require it.
- Process acknowledgements and partial failures explicitly.
- Trigger synchronization on reconnect and supported foreground/background events.
- Surface pending, syncing, succeeded, failed and conflict states.

## Acceptance criteria

- Implemented shared queue and retry processing in `src/offline/sync.ts`.
- `src/offline/transport.ts` sends `X-Idempotency-Key` using the client operation ID.
- Failed operations remain in IndexedDB and are retried by the status component.
- The Rails API must still implement idempotency persistence and domain-specific conflict responses before production synchronization is enabled; this is not silently assumed to exist.