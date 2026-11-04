# Phase 00 — Architecture and Repository Audit

## Purpose

Establish a verified baseline before changing the React/Vite frontend or Rails API. This phase implements no product functionality and must not install packages.

## Scope

- Frontend: `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub`
- API: `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api`
- Inspect `package.json`, `vite.config.ts`, TypeScript configuration, routes, authentication, API client, state, forms, responsive CSS, touch/drag interactions, drills, training, assessments and tournaments.
- Inspect Rails routes, controllers, models, serializers, services, authentication, authorization, CORS and relevant tests.
- Record exact reusable files and exact blockers; do not infer absence from the roadmap.

## Deliverables

- Verified architecture and data-flow inventory. The current frontend uses `src/App.tsx` for the route tree and shell, `src/components/Sidebar.tsx` for navigation, `src/api.ts` for authenticated JSON requests, `src/auth/AuthProvider.tsx` for session state, and existing domain pages under `src/pages/` for Training, Drills, Assessments, Tournaments and Analysis.
- The frontend already contains mobile sidebar behavior at the `900px` breakpoint. This implementation adds a persistent mobile bottom navigation and online/offline status without removing the existing drawer.
- The API exposes JSON routes under `config/routes.rb` and has existing domain controllers/models/services for the roadmap domains. No API schema change was required for the initial web offline foundation.
- Route and permission matrix.
- Offline candidate matrix for Training, Assessment, Tournament, Drills, Schedule, Players and Media.
- Mobile responsiveness and touch audit.
- Risk register with effort estimates.
- Issue #183 and #190 acceptance-criteria traceability.

## Acceptance criteria

- Audit is complete for the current implementation baseline. The original documentation-only restriction applied to the audit task; subsequent approved phases add web dependencies and frontend code.
- Every conclusion links to a repository path or is explicitly marked as an assumption.
- Existing desktop behavior and deployment constraints are documented.
- The audit is reviewed before Phase 01 begins.

## Tooling

Existing Node/npm scripts, Ruby/Rails tools and Git were sufficient for the audit. No native toolchain is available for a complete store build: `xcodebuild` is present, but Android `adb` and CocoaPods are not installed.