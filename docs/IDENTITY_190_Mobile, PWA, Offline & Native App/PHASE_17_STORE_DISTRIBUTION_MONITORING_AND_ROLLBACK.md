# Phase 17 — Store Distribution, Monitoring and Rollback

## Purpose

Prepare signed Android/iOS releases and operate them safely.

## Requirements

- Android Play Console, signing, icons, screenshots, privacy policy and release tracks.
- iOS certificates, provisioning, TestFlight, App Store Connect and privacy declarations.
- Crash, API, sync, conflict and offline-usage monitoring.
- Emergency rollback and data-recovery procedures.
- Separate store, hosting and monitoring costs from free/open-source development dependencies.

## Acceptance criteria

- Documentation is complete, but store distribution is not executed. It requires store accounts, signing credentials, native platform projects and real-device validation.
- Android and iOS release checklists are complete.
- Builds are reproducible and signed through documented credentials/processes.
- Monitoring includes sync success rate and unresolved conflict rate.
- Rollback does not discard locally queued user data.