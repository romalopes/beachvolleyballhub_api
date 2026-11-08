# Phase 04 — Mobile Training Workflow

## Purpose

Allow a coach to download and run a training session at the beach without continuous connectivity.

## Requirements

- Explicitly download a training session and its required drills, players and selected media.
- Support offline startup, attendance, notes and session progress.
- Persist important actions immediately instead of relying on a final Save button.
- Survive reload, browser termination, device sleep and app restart.
- Show pending, synchronized, failed and stale states.

## Acceptance criteria

- Training attendance updates now fall back to the shared offline queue in `src/pages/TrainingDetail.tsx` through `src/offline/domainMutations.ts` when the API is unavailable.
- Failed generic operations are retained and tested by `src/offline/sync.test.ts`.
- Full training download, notes and session-progress persistence still require endpoint-by-endpoint integration.