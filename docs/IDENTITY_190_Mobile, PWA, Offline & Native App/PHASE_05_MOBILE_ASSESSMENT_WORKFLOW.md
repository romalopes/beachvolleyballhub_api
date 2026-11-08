# Phase 05 — Mobile Assessment Workflow

## Purpose

Capture player assessments reliably under poor or unavailable connectivity.

## Requirements

- Persist each assessment score and observation immediately to local storage.
- Support interrupted assessments and resume behavior.
- Validate locally for usability, then validate authoritatively on the API.
- Preserve assessment history and identify stale player/profile data.
- Never discard a draft because a request failed.

## Acceptance criteria

- Assessment score saves now fall back to the shared offline queue in `src/pages/AssessmentSessionDetail.tsx` through `src/offline/domainMutations.ts` when the API is unavailable.
- Generic sync failures are visible through the shared status component and retained locally.
- Observation-specific actions, local draft restoration and backend conflict responses remain required.