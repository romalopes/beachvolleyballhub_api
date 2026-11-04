# Phase 03 — Mobile Drills and Drill Viewer

## Purpose

Adapt drill browsing, viewing and any editor interactions for touch and explicit offline downloads.

## Requirements

- Audit the existing drill components before reuse or refactoring.
- Support downloaded drill metadata and selected media offline.
- Replace hover-only actions with visible touch-safe controls.
- Define unavailable, stale, loading and media-storage states.
- Treat video download as optional and storage-aware.

## Acceptance criteria

- The shared offline cache supports drill records, but the existing Drills read workflow has not yet been wired to populate it; downloaded-drill offline acceptance is therefore pending.
- Existing responsive layout and route remain intact; touch-editor audit is pending from Phase 00's exact component inventory.
- Server-side permissions remain unchanged and continue to be enforced by the existing API.