# Phase 01 — Shared Mobile Architecture and Data Contracts

## Purpose

Define one React application, one Rails API, one permission model and shared domain contracts for online and offline operation.

## Design requirements

- Rails/PostgreSQL remains authoritative; IndexedDB is temporary operational storage.
- Use shared repositories and a shared sync engine rather than separate TrainingSync, AssessmentSync and TournamentSync systems.
- Define stable server IDs, client operation IDs, timestamps, versions, ownership and organization scope.
- Define explicit download boundaries and stale-data behavior.
- Preserve server-side RBAC, membership, visibility and ownership checks.

## Deliverables

- Architecture diagram and module boundaries.
- Domain contract for Training, Assessment, Tournament, Drill, Schedule, Player and Media records.
- Read/write matrix showing online, offline and server-validation behavior.
- Idempotency and conflict contract.

## Acceptance criteria

- All later phases can reference the same contracts.
- No client-only authorization is treated as security.
- Data ownership and organization isolation are explicit.