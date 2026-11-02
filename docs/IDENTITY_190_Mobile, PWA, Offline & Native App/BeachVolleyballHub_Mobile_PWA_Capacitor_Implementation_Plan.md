# Beach Volleyball Hub — Mobile, PWA, Offline & Capacitor Implementation Plan

**Version:** 1.0 · **Date:** 2026-11-01  
**Repositories:** [Frontend](https://github.com/romalopes/beachvolleyballhub_frontend) · [Rails API](https://github.com/romalopes/beachvolleyballhub_api)  
**Legacy requirements:** [API issue #183](https://github.com/romalopes/beachvolleyballhub_api/issues/183) · [API issue #190](https://github.com/romalopes/beachvolleyballhub_api/issues/190)

> **Verification status:** This is an implementation-ready **provisional architecture**, not a completed source audit. Live GitHub repository files and issue bodies could not be retrieved in this environment. Phase 0 explicitly requires reading both issues and both repositories, recording exact paths, and updating this plan before coding. Do not assume that an entity, route, notification system, or feature is absent merely because it is described here. Do not delete or rewrite existing functionality without evidence.

## 1. Decisions and non-negotiable requirements

- **One application:** retain the existing React/TypeScript/Vite frontend and Rails API; no React Native rewrite or new mobile frontend repository.
- **Desktop protection:** existing desktop navigation, workflows and URLs must continue to work. Build on a feature branch and Cloudflare Pages preview, with feature flags and rollback.
- **Home:** retain the current desktop Home content, hierarchy and visual identity; reflow existing cards, weather, map, nearby organisations, training and tournaments for narrow screens. Audit what Home actually renders before implementing.
- **Bottom navigation:** **Drills | Training | Tournaments | Assessments | Analysis**. Header logo returns Home; header/drawer contains account, organisations, coaches, players, locations, notifications if present, and administration. The five labels remain visible or accessible with adequate touch targets.
- **Permission-driven:** preserve Rails RBAC, organisation scope, role/permission overrides, ownership, visibility and membership rules. Never rely on client-side navigation hiding for security.
- **Offline-first where it matters:** critical coaching workflows are Training attendance and Assessment capture. Drills and downloaded session materials are read offline. Analysis drafts are offline; video transfer is constrained. Tournament schedules can be cached but official results require validation.
- **Native:** Capacitor Android **Phase 14**, Capacitor iOS **Phase 15**, immediately after PWA/offline/push phases, as agreed. Do not postpone to an undefined future.
- **Free software:** use free/open-source libraries; no mandatory paid sync service. Hosting usage and app-store distribution may still cost money.
- **Reuse existing systems:** notifications, location/geocoding, weather, authentication, assessments, analysis, organisations, drills, training, tournaments, media, storage and tests should be audited and extended—not duplicated.

## 2. Platform model

```text
                    Shared React/Vite application
                      |       |         |
                 Desktop   Mobile Web   Capacitor Android/iOS
                      \       |         /
                  Shared routes, hooks, RBAC-aware UI
                             |
                    Domain repositories
                       /          \
                 Online API     Dexie/IndexedDB
                      |              |
                 Rails API      Pending operation queue
                      |              |
                  Neon PG  <--- authorised, idempotent sync
                      |
            Existing jobs / notifications / storage
```

**Responsive detection:** CSS viewport media queries and container queries; use `matchMedia` only for behavioural differences. Do not branch by user-agent. Use `Capacitor.isNativePlatform()` only for native capabilities (push, camera, filesystem, secure storage), not layout.

**Responsive strategy:** default to current desktop markup; add scoped mobile styles and small mobile-only components. Prefer shared page components and shared domain logic. Do not render both heavy desktop/mobile trees when hidden with CSS if they trigger duplicate requests or subscriptions.

**Illustrative breakpoints:** `<768px` mobile, `768–1023px` tablet, `>=1024px` desktop; validate against actual layouts and accessibility zoom. Respect iOS safe areas and keyboard overlay.

## 3. User journeys and mobile information architecture

### Home (public where existing permissions allow)

Header: hamburger/drawer, clickable BVH brand/Home, account/avatar, notifications if already supported. Keep existing Home sections in their existing semantic order unless usability tests suggest otherwise. Render weather as a compact forecast, nearby organisations as cards, location search/map with expandable map, nearby training/tournaments and relevant drill discovery. Preserve browser geolocation → IP fallback → Coogee fallback behaviour only if verified in code; show the resolved location and an explicit change-location control. Do not request GPS repeatedly or require location to browse.

### Bottom tabs

| Tab | Primary mobile use | Coach/manager action | Offline target |
|---|---|---|---|
| Drills | Browse/search by skill, stage, difficulty, player count; diagrams | Select for training; create/edit where feasible | Saved drill details/diagrams; bounded media |
| Training | Upcoming/nearby/mine, session detail, attendance | Start session, check in, choose drills, notes | Downloaded session roster, attendance, notes |
| Tournaments | Discover, registration, schedules, results | Manage permitted tournament workflows | Cached schedule/details; draft results only if validated |
| Assessments | View own authorised results | Select template, score players, notes, next/previous | **Critical**: full capture with pending sync |
| Analysis | View authorised videos, notes, linked players | Draft analysis, link training/tournament/assessment | Notes/metadata drafts; bounded media |

Drawer: Home, Organisations/Groups, Players, Coaches, Locations, Membership/Invitations, Notifications (if present), Settings, Admin (authorised only), Sign in/out. Avoid a second permanent bottom tab for Home; logo/header is the Home affordance. On small phones verify labels and accessible hit areas (minimum 44×44 CSS px recommended).

### Coaching focus mode

From a training session, **Start Session** opens a streamlined screen: participants → attendance → selected drills → assessment shortcuts → notes → finish/sync status. Keep the same canonical session and assessment records as desktop. For assessment scoring, use the actual template's scale/weights, not a hard-coded 1–5 control. Support rapid switching among players, autosave and explicit pending-sync indicators.

## 4. Offline data and sync contract

### Storage boundaries

- **Service worker/Workbox:** app shell, versioned static assets, safe public GET responses where appropriate. Do **not** indiscriminately cache authenticated API responses.
- **Dexie/IndexedDB:** versioned local records for downloaded drills, sessions, participants, assessment templates/results, tournament schedules, analysis drafts, selected locations, and queued operations. Include `userId`, tenant/organisation scope, server version, fetch time and sync status.
- **Large video:** avoid automatic downloads. Explicit opt-in, storage quota, clear/remove controls, bounded file size; Capacitor filesystem can be considered for native later.
- **Weather:** show last-updated timestamp and a stale indicator; never present stale conditions as live safety advice.
- **Maps:** do not promise offline Google Maps tiles; licensing and offline terms vary. Cached coordinates, addresses and directions links are safer initial offline support.

### Operation queue schema (illustrative)

`id` (UUID), `userId`, `organisationId`, `entityType`, `entityId`, `operationType`, `payload`, `idempotencyKey`, `baseVersion`, `createdAt`, `attempts`, `status` (`pending|syncing|failed|conflict|synced`), `lastError`. Preserve operation ordering within an entity; do not assume global ordering across unrelated entities.

### Sync rules

1. Queue only an explicit allowlist of operations: attendance, assessment draft/result entries, session notes, analysis notes; expand carefully.
2. On reconnect, login refresh and app foreground, authenticate and fetch current permissions before replaying writes.
3. Server uses idempotency keys (unique per actor+operation) to prevent duplicate submissions after retries.
4. Use optimistic concurrency (`lock_version`, ETag/If-Match, or equivalent verified mechanism) for shared mutable records. On conflict, show server/local differences; never silently overwrite another coach's assessment.
5. Different coaches' assessments remain independent according to existing data model. Do not merge scores across coaches client-side unless domain rules require it.
6. Preserve failed drafts until explicit resolution; never discard on network error. Show pending count and last successful sync.
7. Logout/account switch clears or securely partitions user-scoped data; revoke offline access for restricted content according to product policy. A PWA cannot guarantee OS-level encryption of IndexedDB.
8. Queue replay must validate Rails permissions, record visibility, organisation membership, and any event status/deadline rules at execution time.
9. For media, separate metadata from uploads; support retries/checksums later. Do not put large video blobs into JSON mutation queues.

## 5. Tools, installation and costs

| Component | Use | Free? | When |
|---|---|---|---|
| Existing React/TypeScript/Vite/CSS | UI and routing | Yes | Existing |
| `vite-plugin-pwa` + Workbox | Manifest, service worker, asset caching | Yes, OSS | Phase 8 |
| `dexie` | IndexedDB local persistence | Yes, OSS | Phase 9 |
| Browser APIs (`matchMedia`, Notifications, Push, IndexedDB) | Responsive/device integration | Yes | As needed |
| `web-push` Ruby gem | Rails → browser push (if no existing equivalent) | Yes, OSS | Phase 13 |
| Rails Active Job + durable adapter (e.g. Solid Queue if compatible) | Reliable background delivery | Yes, OSS; hosting resources may cost | Phase 13 |
| Vitest / React Testing Library / Playwright | Unit/component/E2E/mobile viewport | Yes, OSS | Phase 0 onward; reuse existing |
| RSpec | Rails contracts/security | Yes, OSS | Existing |
| Lighthouse / Chrome DevTools | PWA and performance audits | Yes | Phase 8 onward |
| `@capacitor/core`, `@capacitor/cli`, `@capacitor/android`, `@capacitor/ios` | Native containers | Yes, OSS | Phases 14–15 |
| Android Studio + SDK/emulator | Android builds/tests | Yes | Phase 14 |
| Xcode + iOS simulator (macOS) | iOS builds/tests | Yes | Phase 15 |
| `@capacitor/push-notifications` | Native push | Yes | Phases 14–15 |
| `@capacitor/camera`, filesystem plugins | Photos/media, if required | Yes | Phase 16 |
| FCM and Apple APNs | Native push transport | Standard push delivery free; Apple distribution constraints apply | Phases 14–15 |
| Cloudflare Pages, Render, Neon, R2, Brevo | Existing infrastructure | Free tiers/usage limits; **not guaranteed $0** | Existing |

**Optional:** TanStack Query if not already present and justified by current hooks. Avoid introducing both Dexie and another offline database library. No Firebase Firestore, paid offline-sync platform or new backend is required.

**Store publication fees (not software licences):** Google Play developer registration commonly US$25 one time; Apple Developer Program US$99/year for standard App Store distribution (check current official terms before publishing). You can deploy/install a PWA without app-store fees. Free Apple device testing has provisioning limitations.

**Install only when phase begins:**

```bash
# Phase 8
npm install -D vite-plugin-pwa
# Phase 9
npm install dexie
# Phase 13, backend only if Web Push isn't implemented
bundle add web-push
# Phase 14
npm install @capacitor/core @capacitor/android
npm install -D @capacitor/cli
npx cap init
npx cap add android
# Phase 15
npm install @capacitor/ios
npx cap add ios
# Native push, after reviewing current notification stack
npm install @capacitor/push-notifications
```

**Before installing:** verify current Node/Vite/Rails versions against the selected versions' official compatibility matrices; pin versions in lockfiles. Capacitor's current major version may require a newer Node runtime than the existing project. `npx cap init` must be configured with the real web build output and a stable app ID. On every native change: `npm run build && npx cap sync`.

## 6. Delivery, flags and rollout

- Branch: `feature/mobile-pwa`; separate preview deployment and preview environment variables. Production stays unchanged until phase acceptance.
- Example flags: `VITE_MOBILE_LAYOUT_ENABLED`, `VITE_PWA_ENABLED`, `VITE_OFFLINE_ENABLED`, `VITE_PUSH_ENABLED`. Vite flags are **build-time**; use Rails remote configuration for emergency runtime kill switches where needed.
- Progressive enablement: responsive UI → PWA shell → read-only cache → offline writes → push → native wrappers.
- Additive Rails migrations; do not alter existing desktop endpoints incompatibly. API changes should be backward-compatible and covered by request specs.
- Avoid enabling service workers on the production origin until caching and update behavior are tested. Preview origin should be isolated.
- Rollback: disable flags/redeploy, unregister problematic service workers safely, retain unsynced drafts, and avoid irreversible IndexedDB schema changes.
- Track metrics: mobile error rate, Core Web Vitals, offline queue size/failure rate, sync latency, push delivery errors, API request rate and storage usage. Reuse Sentry/observability if already configured.

## 7. Phase-by-phase plan and AI coding prompts

> **How to use prompts:** Run one phase at a time with access to both repositories. Require the coding assistant to show audited file paths, tests, migration impact and a diff summary. Never permit broad refactors outside the phase scope. Prompts assume the AI can inspect the local repository; if it cannot, supply files or connect GitHub first.

### Phase 0 — Repository and legacy issue audit

**Objective:** reconcile issues #183/#190 with today's system and identify exact reusable code. **No implementation changes.**

**Tasks:**
1. Read complete bodies, comments and acceptance criteria of issues #183 and #190; classify each requirement: still relevant, implemented, superseded, conflicting or unknown.
2. Audit frontend `package.json`, Vite config, routes, navigation, Home, responsive CSS, authentication, API clients, state/query libraries, drill builder/viewer, training, tournament, assessment, analysis, location/weather/maps, upload/media, notifications and tests.
3. Audit Rails routes/controllers/models/policies/services/jobs/migrations/tests for the same domains, including organisation scopes, attendance, assessment template/versioning and existing notifications.
4. Inspect PWA/service worker/manifest, push subscriptions and any existing offline storage. Check production/preview deployment configuration and Node version.
5. Produce a verified inventory (`existing/reuse/extend/new`), dependency graph, risk register, endpoint contracts and a list of corrections to this plan.

**Acceptance:** exact source paths and issue quotes are recorded; no speculative claims are labelled verified.

**AI prompt:**
```text
Audit beachvolleyballhub_frontend and beachvolleyballhub_api for a mobile/PWA/Capacitor roadmap. Read GitHub API issues #183 and #190 in full, including comments. Do not modify code. Inventory the current Home.tsx, routing, nav, responsive styles, Drills, Training, Tournaments, Assessments, Analysis, authentication, RBAC, notifications, weather/maps, storage, tests and deployments. Identify exact files, endpoints, schema relationships, existing mobile/offline support, and obsolete issue requirements. Output a matrix: requirement | current implementation with file:line evidence | gap | recommended change | risk | tests. Explicitly mark inaccessible items unknown. Update the roadmap only after this audit.
```

### Phase 1 — Architecture, flags, baseline tests

**Tasks:** establish branch and Cloudflare preview; capture desktop screenshots for key routes; add narrowly scoped flags; document breakpoint policy, native adapter interface and offline repository interface; define PWA/native threat model; verify CI. Do not install offline/native libraries yet.

**Acceptance:** production desktop screenshots unchanged; preview and flags verified; baseline tests pass.

**AI prompt:**
```text
Implement Phase 1 only. Based on the audited code, create a feature/mobile-pwa branch plan, build-time mobile/PWA/offline/push flags with safe defaults, shared mobile design tokens, and regression snapshots for existing desktop routes. Preserve all existing route names and API contracts. Do not introduce separate desktop/mobile apps or a new state library. Add tests for flag behavior. Return changed files, commands, and rollback steps.
```

### Phase 2 — Mobile navigation and responsive Home

**Tasks:** bottom tabs Drills/Training/Tournaments/Assessments/Analysis; logo navigates Home; accessible drawer for secondary sections; account controls; adapt existing Home weather/map/nearby cards/search with location state preserved. Hide desktop navigation only at appropriate breakpoints; avoid duplicate mounts/network calls.

**Acceptance:** Home visually resembles desktop content on 360/390/430px phones, tablets and desktop; tabs keyboard/screen-reader accessible; public Home still works signed out; desktop screenshots unchanged.

**AI prompt:**
```text
Implement Phase 2 using the actual existing Home and navigation components. Preserve the desktop Home content and behavior. At mobile widths add a fixed, safe-area-aware five-item bottom nav: Drills, Training, Tournaments, Assessments, Analysis. Header brand links Home; a drawer exposes Organisations, Groups, Players, Coaches, Locations, Account, Settings and authorised Admin options. Reuse current RBAC and location/weather/map logic. Do not duplicate route trees or data fetching. Add Playwright viewport and accessibility tests at 360, 390, 768, 1024 and 1440px. Keep mobile behind its feature flag.
```

### Phase 3 — Drills mobile UX

**Tasks:** browse/filter/detail; diagrams adapt to portrait/touch; selected drill lists and save/download affordances; defer advanced diagram authoring until tested. Reuse existing drill JSON/schema/validation and media model.

**Acceptance:** filters, viewing and training selection work without regressions; long diagrams remain legible.

**AI prompt:**
```text
Adapt existing Drill list/detail/selection components for touch and narrow screens. Audit and reuse current drill schema, builder, SVG/canvas annotations and training links. Provide mobile filters, readable diagrams, accessible gestures and an explicit 'save for offline' affordance wired to a placeholder repository until Phase 9. Avoid rewriting the drill builder. Add component/E2E tests for filtering, selection, zoom, permissions and desktop parity.
```

### Phase 4 — Training mobile UX

**Tasks:** list, upcoming/mine/nearby, detail, roster, location/map, drills, recurring-session relationship; coaching focus mode; attendance and notes UI. Design data boundaries for offline queue without enabling offline writes yet.

**Acceptance:** coaches can run a session online with touch-friendly controls; players see only authorised sessions.

**AI prompt:**
```text
Create a mobile-first presentation for existing Training Session workflows, including list/detail, participants, location, selected drills, recurring template association where present, and a Start Session coaching flow. Reuse current API, permissions and session models. Design attendance and notes mutations through a repository interface so Phase 10 can add offline storage. Do not create new training records or duplicate existing API endpoints. Test public/private visibility, coach vs player permissions, and desktop regression.
```

### Phase 5 — Tournaments mobile UX

**Tasks:** responsive discovery, registration, schedules/results, compact bracket/list views; separate player view from organiser actions; leave bulk bracket editing desktop-first if necessary.

**Acceptance:** key public and authenticated tournament journeys work on phones; server owns official results.

**AI prompt:**
```text
Audit and adapt current Tournaments UI to mobile: discover/filter, detail, registration, schedule, standings/results and permitted organiser actions. Reuse existing tournament domain rules and API. Provide compact list views when desktop tables/brackets overflow. Do not implement offline authoritative score submission. Add tests for permissions, registration state, schedule changes, narrow viewport and desktop parity.
```

### Phase 6 — Assessments mobile UX

**Tasks:** list/session detail; template-based scoring using existing scale/weights; next/previous player; autosave drafts; clear saved/pending states; guard accidental navigation; preserve per-coach independence.

**Acceptance:** complete assessment online on a phone; no lost inputs or hard-coded scale.

**AI prompt:**
```text
Implement touch-first Assessment session entry using existing assessment templates, scales, weights, evaluated player relationships and per-coach ownership. Provide large score controls, next/previous player, notes, autosave via a repository boundary, and visible save state. Preserve existing calculations and authorization. Do not assume all templates use a 1–5 scale. Test template variants, multiple coaches, rapid switching, interruptions and desktop parity.
```

### Phase 7 — Analysis mobile UX

**Tasks:** mobile list/detail, linked training/tournament/assessment, player selection, notes/comments, URL video and uploaded media; explicit future 'Hire Analysis' affordance if current feature supports it. Plan media lifecycle, do not auto-cache video.

**Acceptance:** authorised analysis viewing and notes work on phone; links and visibility are correct.

**AI prompt:**
```text
Audit existing Analysis feature before coding. Make list/detail/video viewing/player selection/notes/comments and links to Training, Tournament and Assessment responsive. Preserve existing media URLs/uploads, visibility and permission checks. Add draft-state UX designed for future offline support. Do not introduce automatic video downloads or new media storage. Add tests for private analyses, playback, navigation and desktop parity.
```

### Phase 8 — Installable PWA

**Tasks:** install `vite-plugin-pwa` if absent; manifest/name/icons/theme; Workbox app-shell strategy; offline fallback; service-worker updates, safe caching, install UI; ensure no authenticated API responses cached indiscriminately. Test iOS Home Screen and Android install flows.

**Acceptance:** Lighthouse PWA checks, app installation, offline shell, clean update and rollback; no stale authenticated data leak.

**AI prompt:**
```text
Implement an installable PWA in the existing Vite frontend. First inspect any current manifest/service worker. Add vite-plugin-pwa only if needed, correct icons, scope/start_url, safe precache rules and explicit update UX. Do not cache authenticated API GETs with generic runtime rules. Preserve Cloudflare Pages routing and existing Sentry instrumentation. Test offline shell, update from version N to N+1, iOS Home Screen behavior, and rollback. Document exact config and free dependency versions.
```

### Phase 9 — IndexedDB, repositories and offline downloads

**Tasks:** add Dexie; versioned schema; repositories for drills, training snapshots, assessment templates/results, analysis drafts and tournament schedules; download controls, cache freshness, quotas, account/tenant partitioning; network/foreground listeners. No queued server mutations yet.

**Acceptance:** selected content survives reload/offline, cache can be cleared, account isolation holds.

**AI prompt:**
```text
Introduce Dexie as the only IndexedDB wrapper. Build versioned local schemas and domain repository interfaces for downloaded Drills, Training/rosters, Assessment templates/drafts, Analysis notes and Tournament schedules. Keep existing API clients as online source of truth. Add explicit save/remove offline controls, freshness timestamps, quotas and account/organisation partitioning. Implement no write replay yet. Test migrations, offline reload, stale data, logout and account switching.
```

### Phase 10 — Offline Training and Assessments

**Tasks:** download a session and roster before coaching; offline attendance/notes; offline assessment scores and notes; autosave per field/player; queued operations; server idempotency and concurrency support. Resolve existing API and schema specifics before adding endpoints.

**Acceptance:** complete a session in airplane mode, restart app, reconnect and sync exactly once; conflicts surfaced.

**AI prompt:**
```text
Implement critical offline coaching workflows on top of Phase 9 repositories: download authorised Training Session data/roster, record attendance and notes, capture Assessment results per coach/template/player, autosave locally and queue explicit allowed mutations. Audit current Rails endpoints and add minimal backward-compatible idempotency/concurrency support where needed. Preserve server-side RBAC and assessment ownership. Test airplane mode, browser restart, retries, duplicate submission, concurrent edits, deleted players and revoked membership. Show pending/conflict/failed states.
```

### Phase 11 — Offline Drills, Analysis and Tournaments

**Tasks:** downloaded drill diagrams/media metadata; analysis text drafts and local media references; cached tournament schedules; optional result drafts without automatic authoritative publication. Bound media storage; provide purge controls.

**Acceptance:** cached drill/session materials readable offline; analysis drafts survive restart; tournament data marked stale.

**AI prompt:**
```text
Extend the existing offline repositories to selected Drill details/diagrams, Analysis notes/metadata drafts and Tournament schedule snapshots. Add explicit download and purge controls. Do not promise offline map tiles or download every video. Treat tournament schedules as potentially stale; server must validate any later result mutation. Add quota/error handling, media size limits, offline UI labels and tests for eviction and reconnect.
```

### Phase 12 — Synchronisation, security and conflicts hardening

**Tasks:** queue lifecycle, retry/backoff, idempotency keys, per-entity ordering, optimistic version checks, permission revalidation, dead-letter/conflict UI, auth expiry, logout policy, storage quota, observability. Test background sync as enhancement only; foreground resume must work.

**Acceptance:** zero silent data loss in test matrix; no cross-account leakage; explicit conflict resolution.

**AI prompt:**
```text
Harden the offline sync engine and Rails write contracts. Add idempotency keys, bounded exponential retries, per-record ordering, optimistic concurrency, authenticated replay, tenant/organisation RBAC checks, conflict UI, audit logs and metrics. Ensure pending drafts are not deleted on failure. Test token expiry, account switch, revocation, simultaneous coach edits, server validation errors, offline-to-online transitions and interrupted uploads. Never use blanket last-write-wins for assessments or official results.
```

### Phase 13 — Existing notifications audit and Web Push

**Tasks:** audit whether notification model, bell, endpoints and jobs already exist; reuse them. Add event triggers for training changes/cancellation, tournament changes, assessment publication, analysis sharing, invitations/membership and comments only if missing. Add Web Push subscriptions, service-worker handlers, opt-in, preferences, unsubscribe, deep links and push-job durability. Avoid duplicate notifications for overlapping audiences.

**Acceptance:** existing bell unchanged on desktop; installed supported PWAs receive opt-in push; in-app history remains canonical even if push fails.

**AI prompt:**
```text
Inspect Beach Volleyball Hub's current notification models, bell, controllers, jobs and event producers first. Reuse everything already implemented. Extend with Web Push (VAPID), per-device subscriptions, opt-in UI, preferences, invalid-endpoint cleanup, deduplicated recipient resolution and deep links for Training, Tournaments, Assessments, Analysis and invitations. Use durable jobs if needed; no duplicate notification table. Do not expose private player or assessment data in push payloads. Test browser permission denial, revoked subscriptions, duplicate followers, logged-out devices and desktop bell regression.
```

### Phase 14 — Capacitor Android (same placement as Wine Words)

**Tasks:** install Capacitor core/CLI/Android, configure app ID/name/build output, create Android project within frontend repository, verify deep links, navigation, auth callback, camera permissions where relevant, Android push token registration (FCM) and lifecycle-triggered sync. Keep browser PWA path unchanged.

**Acceptance:** signed Android debug build on emulator and physical device; same routes/permissions; sync after resume; push opens correct record.

**AI prompt:**
```text
Add Capacitor Android to the existing React/Vite frontend, without creating a second app. Audit Node/Vite compatibility, set a stable appId, webDir and Android package name, and add android/ with reproducible build instructions. Abstract native push via Capacitor and reuse the existing Rails notification API, supporting FCM registration/token rotation. Verify auth/deep links, offline Dexie persistence, safe-area/navigation bars, permissions, foreground/background lifecycle and Playwright/browser parity. Do not require Google Play publication. Include free tool setup and Android emulator/device tests.
```

### Phase 15 — Capacitor iOS (same placement as Wine Words)

**Tasks:** add iOS target using Xcode/macOS; configure app identifier, signing for local testing, universal links/deep links as applicable, safe areas, keyboard, permissions, APNs token handling, foreground resume and storage. Keep PWA and Android working.

**Acceptance:** iOS simulator and physical device where available; no layout clipping; offline recovery; push validated on real device with appropriate signing/capabilities.

**AI prompt:**
```text
Add Capacitor iOS to the same frontend repository after Android. Use the actual project Node/Capacitor compatibility matrix and document Xcode/macOS requirements. Configure app identifier, entitlements/signing for permitted local tests, safe areas, keyboard handling, navigation, deep links and native APNs registration through the existing notification endpoint abstraction. Verify Dexie offline data, logout, app resume, update behavior and iOS PWA parity. Distinguish free local development from paid App Store distribution. Do not require an App Store release.
```

### Phase 16 — Native media, camera and coaching ergonomics

**Tasks:** introduce Capacitor Camera/Filesystem only where needed for Analysis and training media; handle permissions, uploads, large files, offline draft references, cleanup, security; evaluate video capture quality, battery/storage and privacy. Avoid replacing browser APIs unnecessarily.

**Acceptance:** users can capture/attach permitted media, recover from failed uploads, remove local copies, and understand storage usage.

**AI prompt:**
```text
Add narrowly scoped native camera/file integration for authorised Analysis and coaching workflows using free Capacitor plugins. Reuse existing Rails media endpoints and R2/ActiveStorage flow; do not create a new media backend. Support capture, preview, user-controlled upload, retry, cancellation, file-size validation, permission denial, local cleanup and privacy. Keep browser file upload functional. Test Android/iOS storage pressure and interrupted uploads; avoid caching video automatically.
```

### Phase 17 — Full regression, accessibility, performance and release

**Tasks:** complete end-to-end matrix across desktop/mobile/PWA/Android/iOS; screen readers, zoom, reduced motion, landscape, low connectivity, storage quota, concurrent edits, role/tenant access, notification permission states, service-worker upgrades, battery/network and security. Stage rollout with monitoring, kill switches and rollback.

**Acceptance:** all critical journeys pass; no desktop regression; offline data not lost; production rollout is reversible.

**AI prompt:**
```text
Perform a release audit for all Beach Volleyball Hub mobile phases. Produce an executable test matrix covering guest/player/coach/curator/admin and scoped permissions across desktop Chrome/Safari, Android Chrome/PWA/Capacitor and iOS Safari/Home Screen PWA/Capacitor. Validate Home parity, five-tab navigation, Drills, Training, Tournaments, Assessments, Analysis, offline sync, token expiry, account switching, conflicts, push, accessibility and performance. Run existing CI and add missing automated coverage. Report exact failing tests, measured metrics, rollout flags, rollback plan and unresolved blockers. Do not silently change domain logic to satisfy tests.
```

## 8. Cross-phase test matrix

| Scenario | Expected result |
|---|---|
| Desktop at 1440px after mobile feature enabled | Same navigation, routes, data and core interactions as baseline |
| Phone at 360px | Five tabs usable, no horizontal overflow, safe-area padding |
| Signed-out Home | Public content renders without auth-only API errors |
| Player opens private assessment | Access denied unless specifically authorised |
| Coach downloads session then loses signal | Roster and templates remain accessible; inputs saved locally |
| App closes during assessment | Local draft persists; pending sync visible on reopen |
| Same operation retries three times | Exactly one server mutation via idempotency |
| Another coach updates shared record | Version conflict shown; no silent overwrite |
| User changes organisation or logs out | Offline data isolated/cleared per policy |
| Weather cached offline | Explicit timestamp/stale badge |
| Tournament schedule changed during offline period | Refresh and conflict/staleness warning |
| Push permission denied | In-app notifications continue; no repeated nagging |
| Notification tapped | Correct authorised route opens; unauthorised data stays protected |
| Service worker updated | No blank screen or permanent stale JS bundle |
| Android/iOS app resumed | Foreground sync and notification refresh work |
| Storage quota exceeded | Clear error, safe eviction, unsynced writes preserved |

## 9. Dependencies and sequencing

```text
0 Audit
  -> 1 Architecture
     -> 2 Navigation/Home
        -> 3 Drills, 4 Training, 5 Tournaments, 6 Assessments, 7 Analysis
     -> 8 PWA
        -> 9 IndexedDB
           -> 10 Training/Assessment offline
           -> 11 Other offline features
              -> 12 Sync/security hardening
                 -> 13 Web Push
                    -> 14 Capacitor Android
                       -> 15 Capacitor iOS
                          -> 16 Native media
                             -> 17 Release hardening
```

Some responsive phases can run in parallel after Phase 2, but shared API/permissions and offline data contracts must be agreed first. Phase 13 may reuse existing notifications and finish earlier if code audit supports it. **Capacitor remains in Phases 14–15** regardless of such optimisation.

## 10. Suggested GitHub issue structure

- Parent epic: Mobile/PWA/Capacitor for Beach Volleyball Hub; link and supersede applicable portions of #183 and #190 only after reading them.
- Child issues: one per Phase 0–17, with dependencies, file-level implementation notes, acceptance criteria and test evidence.
- Separate cross-cutting issues if needed: Offline Security & Sync Contract, Web Push, Mobile Assessment UX, Mobile Training UX.
- Preserve original issue history; add a comment mapping old acceptance criteria to new phases rather than closing old issues without review.

## 11. Master AI implementation prompt

```text
You are the senior engineer implementing the Beach Volleyball Hub mobile/PWA/Capacitor roadmap across beachvolleyballhub_frontend (React/TypeScript/Vite) and beachvolleyballhub_api (Rails). First read the current code, both GitHub issues #183 and #190, and this plan. Treat any unverified architecture assumption as provisional. Preserve the existing desktop Home and navigation, routes, RBAC, organisation hierarchy, training, tournaments, assessments, analysis, notifications, storage and deployments. Mobile bottom tabs must be Drills, Training, Tournaments, Assessments and Analysis; the header logo returns Home. Use one frontend and Rails backend, responsive CSS, vite-plugin-pwa, Dexie, safe idempotent offline sync, Web Push, then Capacitor Android Phase 14 and iOS Phase 15. Use only free/open-source development components; identify any hosting/store costs separately. Implement ONLY the requested phase. Before edits, show current files, reusable code, exact changes, migrations and risks. After edits, provide tests, commands, accessibility/security review, screenshots where applicable, deployment/rollback steps, and a concise diff summary. Never introduce duplicate domain models, bypass server authorisation, overwrite concurrent coach data silently, or change desktop behaviour without explicit approval.
```

## 12. Definition of done

The initiative is complete when: (1) desktop remains regression-free; (2) mobile Home retains existing content; (3) five main tabs work across mobile widths; (4) core Drills, Training, Tournaments, Assessments and Analysis workflows are usable; (5) selected content is available offline; (6) Training/Assessment drafts survive offline restarts and synchronise without duplicates or silent conflicts; (7) existing notifications are reused and push works where supported; (8) Android and iOS Capacitor builds pass device testing; (9) RBAC, organisation isolation and subscription/privacy policies are enforced server-side; (10) there is a documented free-software stack, release checklist and rollback plan.

---

**Next action:** Run **Phase 0** with GitHub/local repository access and update this document with verified code paths and issue-specific acceptance criteria before making code changes.
