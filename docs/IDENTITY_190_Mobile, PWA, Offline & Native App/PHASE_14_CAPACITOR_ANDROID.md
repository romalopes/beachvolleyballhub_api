# Phase 14 — Capacitor Android

## Purpose

Package the stable shared React application as an Android app without creating a second frontend.

## New tooling

```bash
npm install @capacitor/core
npm install -D @capacitor/cli
npm install @capacitor/android
npx cap add android
```

Also required outside npm: Android Studio, Android SDK/platform tools, a compatible JDK and a physical device or emulator.

Install only after PWA, IndexedDB, synchronization and real-device validation are accepted.

## Requirements and acceptance criteria

- Capacitor core, CLI and Android packages are installed, `capacitor.config.ts` is present, and `npx cap add android` generated the Android project.
- Android build/device validation is still blocked until Android Studio, SDK/platform tools, a compatible JDK and an emulator/device are installed.
- Reuse the existing React build and routes.
- Test offline storage, reconnect, sleep/wake, rotation, permissions and app termination.
- Use minimal Android permissions and document each one.
- No Android-only domain model or duplicated UI is introduced.