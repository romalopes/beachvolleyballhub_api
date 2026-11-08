# Phase 07 — PWA Foundation

## Purpose

Make the shared web application installable and able to start offline without treating cached API data as authoritative.

## Requirements

- Add a web app manifest, icons, launch metadata and safe-area support.
- Define application-shell and static-asset caching.
- Define service-worker update, invalidation and rollback behavior.
- Keep domain data in the IndexedDB strategy rather than blindly caching responses.
- Test installability and offline startup on supported browsers.

## New tooling

Likely package, to install only after Phase 00/01 approval:

```bash
npm install -D vite-plugin-pwa
```

Confirm the selected version against the existing Vite version before installation.

## Acceptance criteria

- Implemented in the frontend with `vite-plugin-pwa`, `vite.config.ts`, `index.html` and `src/main.tsx`.
- Production build generates `dist/manifest.webmanifest`, `dist/sw.js` and Workbox assets.
- The service worker is registered with `autoUpdate`; application-shell navigation fallback is configured.
- Browser install and offline device validation remain Phase 11 work and require a browser/device test session.