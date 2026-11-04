# Phase 12 — Web Push and Notification Integration

## Purpose

Extend the existing notification system progressively without making push a dependency for offline operation.

## Requirements

- Audit current Rails and frontend notification code first.
- Reuse existing event, permission and organization concepts.
- Define opt-in, denial, unsupported-browser and token-revocation behavior.
- Keep training, assessment and tournament workflows functional without push.

## Acceptance criteria

- No duplicate notification domain is introduced.
- Push failures do not block synchronization or core workflows.
- Privacy and permission behavior are documented.