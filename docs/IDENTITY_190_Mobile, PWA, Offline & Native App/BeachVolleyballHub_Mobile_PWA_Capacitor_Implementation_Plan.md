# Beach Volleyball Hub — Mobile, PWA, Offline & Capacitor Implementation Plan

**Version:** 2.1
**Date:** 2026-03-11
**Repositories:** [Frontend](https://github.com/romalopes/beachvolleyballhub_frontend) · [Rails API](https://github.com/romalopes/beachvolleyballhub_api)
**Source issues:** [#183](https://github.com/romalopes/beachvolleyballhub_api/issues/183) · [#190](https://github.com/romalopes/beachvolleyballhub_api/issues/190)

## 1. Verified baseline

This plan was reconciled against the local repositories and the two GitHub issue records available during this planning update.

## Implementation status

The initial web/native foundation has now been implemented in the frontend and API. Completed work includes the PWA manifest/service worker, Dexie-based versioned offline storage, a shared pending-operation queue with idempotency headers, connectivity status UI, mobile bottom navigation, offline fallbacks for training attendance and assessment score saves, Rails idempotency persistence/replay, Capacitor Android/iOS project scaffolding and automated synchronization tests. Domain-specific downloads, full training/assessment drafts, tournament scoring API work and native/store validation remain gated by the limitations recorded in the phase documents below.

### Frontend

Path: `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub`

- React `^19.2.8`, React Router `^7.18.3`, Vite `^8.2.2`, TypeScript `~6.0.2`.
- Vitest, Testing Library and ESLint are already configured.
- Existing scripts: `npm run dev`, `npm run build`, `npm run lint`, `npm test`, `npm run test:coverage`, `npm run preview`.
- Current manifest does not include Capacitor, `vite-plugin-pwa`, Dexie or another IndexedDB abstraction.
- Existing frontend source includes authentication, API utilities, training, drills, assessments, tournaments, videos, tests and utility modules; Phase 00 must record exact reuse paths before implementation.
- `src/App.tsx` owns the route tree and shell; `src/components/Sidebar.tsx` owns the existing navigation; `src/api.ts` owns authenticated JSON requests; `src/auth/AuthProvider.tsx` owns session state.
- `src/offline/db.ts`, `src/offline/sync.ts` and `src/offline/transport.ts` now provide the shared web offline foundation.

### API

Path: `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api`

- Rails API and PostgreSQL/Neon remain the canonical backend and data source.
- Rails now persists successful JSON mutation responses keyed by `X-Idempotency-Key` in `api_idempotency_keys`; replaying a key with a different payload returns HTTP 409.
- Existing authorization, organization, identity, training, tournament, assessment, notification and media behavior must be audited and reused rather than duplicated.

## 2. Issue traceability

### Issue #183 — Mobile, PWA, Offline Training, Assessment and Tournament

Open, created September 23, 2026. It defines the product requirement: coaches and tournament organizers must be able to operate Training, Assessment and Tournament workflows at the beach with poor or unavailable connectivity. It requires immediate persistence, a shared offline layer, explicit conflict handling, server authority, PWA installation and no React Native rewrite.

Mapped phases: **00–11**, with release validation in **13–17**.

### Issue #190 — Mobile, PWA, Offline & Native App Implementation Plan

Open, created September 24, 2026. It provides the architecture roadmap: one React/Vite application, Rails as the only backend, IndexedDB for local operational data, a shared synchronization engine, PWA before Capacitor, and Android/iOS native packaging only after the offline foundation is stable.

Mapped phases: **00–17**. Its documentation-only audit requirement is implemented by Phase 00.

## 3. Non-negotiable architecture

- One React/Vite/TypeScript application for desktop, mobile web, PWA, Android and iOS.
- One Rails API; PostgreSQL/Neon remains authoritative.
- IndexedDB is temporary local operational storage, not a replacement database.
- Offline boundaries are explicit: users download a training session or tournament rather than receiving an uncontrolled cache of all data.
- Training, Assessment and Tournament use one offline data layer and one sync engine.
- Important actions are persisted immediately: attendance, notes, assessment scores, observations, tournament scores and match results.
- Failed synchronization never discards local data.
- Tournament conflicts are detected and resolved explicitly.
- Server-side RBAC, organization isolation, ownership, visibility and subscription/privacy rules remain authoritative.
- React Native is not introduced by this roadmap.

## 4. Phase index

| Phase | Document | Outcome |
|---:|---|---|
| 00 | [Architecture and Repository Audit](PHASE_00_ARCHITECTURE_AND_REPOSITORY_AUDIT.md) | Verified baseline, paths, risks and acceptance criteria |
| 01 | [Shared Mobile Architecture and Data Contracts](PHASE_01_SHARED_MOBILE_ARCHITECTURE_AND_DATA_CONTRACTS.md) | Shared domain, permissions, offline and idempotency contracts |
| 02 | [Mobile Navigation and Home Experience](PHASE_02_MOBILE_NAVIGATION_AND_HOME_EXPERIENCE.md) | Responsive navigation while preserving desktop behavior |
| 03 | [Mobile Drills and Drill Viewer](PHASE_03_MOBILE_DRILLS_AND_DRILL_VIEWER.md) | Touch-safe drill use and explicit offline downloads |
| 04 | [Mobile Training Workflow](PHASE_04_MOBILE_TRAINING_WORKFLOW.md) | Offline training operation and durable notes/attendance |
| 05 | [Mobile Assessment Workflow](PHASE_05_MOBILE_ASSESSMENT_WORKFLOW.md) | Immediate offline score and observation capture |
| 06 | [Mobile Tournament Workflow](PHASE_06_MOBILE_TOURNAMENT_WORKFLOW.md) | Offline scoring with explicit result conflicts |
| 07 | [PWA Foundation](PHASE_07_PWA_FOUNDATION.md) | Installable shell and controlled service-worker caching |
| 08 | [IndexedDB Offline Data Layer](PHASE_08_INDEXEDDB_OFFLINE_DATA_LAYER.md) | Versioned local data and pending operations |
| 09 | [Shared Synchronization Engine](PHASE_09_SHARED_SYNCHRONIZATION_ENGINE.md) | Idempotent retryable synchronization |
| 10 | [Offline Security, Recovery and Logout](PHASE_10_OFFLINE_SECURITY_RECOVERY_AND_LOGOUT.md) | Data protection and no-loss recovery behavior |
| 11 | [Real-Device and Browser Validation](PHASE_11_REAL_DEVICE_AND_BROWSER_VALIDATION.md) | Browser, PWA and lifecycle evidence |
| 12 | [Web Push and Notification Integration](PHASE_12_WEB_PUSH_AND_NOTIFICATION_INTEGRATION.md) | Progressive notification support without duplication |
| 13 | [PWA Release Hardening](PHASE_13_PWA_RELEASE_HARDENING.md) | Production rollout, monitoring and rollback |
| 14 | [Capacitor Android](PHASE_14_CAPACITOR_ANDROID.md) | Android packaging from the shared frontend |
| 15 | [Capacitor iOS](PHASE_15_CAPACITOR_IOS.md) | iOS packaging from the shared frontend |
| 16 | [Optional Native Features](PHASE_16_OPTIONAL_NATIVE_FEATURES.md) | Gated camera, filesystem, share, location or native push |
| 17 | [Store Distribution, Monitoring and Rollback](PHASE_17_STORE_DISTRIBUTION_MONITORING_AND_ROLLBACK.md) | Signed releases and operational readiness |

## 5. Dependency graph

```text
00 Audit
  -> 01 Shared contracts
     -> 02 Mobile navigation
        -> 03 Drills, 04 Training, 05 Assessment, 06 Tournament
     -> 07 PWA foundation
        -> 08 IndexedDB
           -> 09 Shared sync
              -> 10 Security/recovery
                 -> 11 Real-device validation
                    -> 12 Web Push
                       -> 13 PWA release hardening
                          -> 14 Capacitor Android
                             -> 15 Capacitor iOS
                                -> 16 Optional native features
                                   -> 17 Store distribution and monitoring
```

Phases 03–06 may proceed in parallel after Phase 01, but they must use the same contracts. Capacitor must not begin before Phases 07–13 are accepted.

## 6. Tooling and installation matrix

### Already installed in the frontend

React, Vite, TypeScript, Vitest, Testing Library, ESLint, React Router and Sentry React are present in `package.json`. No installation is required for the audit or documentation work.

### New npm packages — install only in their approved phase

| Phase | Package/command | Why |
|---:|---|---|
| 07 | `npm install -D vite-plugin-pwa` | Manifest, service worker and PWA integration |
| 08 | `npm install dexie` | IndexedDB schema/repository layer |
| 08 optional | `npm install dexie-react-hooks` | Only if repository hooks require it |
| 14 | `npm install @capacitor/core && npm install -D @capacitor/cli && npm install @capacitor/android` | Android shell |
| 15 | `npm install @capacitor/ios` | iOS shell |
| 16 optional | Capacitor camera/filesystem/share/geolocation/push plugins | Only for approved native use cases |

Versions must be selected against the current Node, Vite, TypeScript and Capacitor compatibility at implementation time. This planning task installs none of them.

For the current implementation, `vite-plugin-pwa@2.0.0`, `dexie@4.4.7`, `fake-indexeddb`, `@capacitor/core`, `@capacitor/cli`, `@capacitor/android` and `@capacitor/ios` were installed in the frontend. `fake-indexeddb` is test-only support for jsdom and is not a production runtime dependency.

### External tools

- Android: Android Studio, Android SDK/platform tools, compatible JDK and emulator/device.
- iOS: macOS, Xcode, iOS SDK, signing setup and Apple Developer account; CocoaPods may be needed by the selected Capacitor/plugin versions.
- Distribution: Google Play Console and Apple Developer/App Store Connect accounts, plus signing certificates and privacy declarations.

Store, hosting and monitoring costs are separate from the free/open-source library policy.

## 7. Testing and release rules

Every implementation phase must report:

- Files inspected and changed.
- Unit, integration, accessibility and end-to-end tests.
- Offline/reconnect evidence where applicable.
- RBAC and organization-isolation review.
- Migration and rollback steps.
- Desktop regression result.

The existing frontend commands are the baseline:

```bash
npm run lint
npm test
npm run build
```

Native phases additionally require real-device builds and lifecycle testing.

## 8. Definition of done

The initiative is complete when:

1. Desktop remains regression-free.
2. Existing Home content and hierarchy remain available on mobile.
3. Drills, Training, Tournaments, Assessments and Analysis are reachable through the mobile navigation.
4. Core Training, Assessment and Tournament workflows operate offline after explicit download.
5. Drafts, observations, scores, attendance and results survive reloads, restarts and connectivity loss.
6. Synchronization is shared, idempotent, observable and does not silently discard or overwrite data.
7. PWA installation and offline startup work on supported browsers.
8. Android and iOS Capacitor builds pass real-device testing.
9. Server-side authorization and organization isolation remain enforced.
10. Release, monitoring, privacy and rollback procedures are documented.

The current implementation pass does not claim completion of real Android/iOS builds, store publication, real-device validation, domain-specific downloads, full training/assessment drafts or tournament scoring. Tournament scoring specifically requires a new API/domain contract because no match-score-result resources currently exist in the API.

## 9. Implementation discipline

Implement one phase at a time. Before editing code, read the relevant phase document and current repository files. Do not introduce duplicate domain models, bypass API authorization, install optional native plugins without a concrete use case, or change desktop behavior without regression evidence.