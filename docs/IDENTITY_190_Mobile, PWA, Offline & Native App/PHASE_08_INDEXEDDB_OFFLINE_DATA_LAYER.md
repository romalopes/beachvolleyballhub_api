# Phase 08 — IndexedDB Offline Data Layer

## Purpose

Provide versioned local storage for explicitly downloaded data and immediately persisted user operations.

## Requirements

- Define stores for downloaded domains, pending operations, sync errors and metadata.
- Add schema versioning and migration rules.
- Isolate records by authenticated user and organization.
- Define quota, eviction and media limits.
- Define logout cleanup without losing pending changes.

## New tooling

Likely package:

```bash
npm install dexie
```

`dexie-react-hooks` is optional and must not be installed unless the audit shows it is needed.

## Acceptance criteria

- Implemented in `src/offline/db.ts` with Dexie version 1 stores for operations, cache and metadata.
- `src/offline/sync.test.ts` validates queue persistence and failure retention using `fake-indexeddb` in Vitest.
- User-scoped cache and operation records are supported; passwords are not stored by the offline layer.
- Domain download population still requires wiring each existing read workflow to `cacheOfflineValue`.