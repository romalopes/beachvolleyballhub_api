# Phase 15 — Capacitor iOS

## Purpose

Package the stable shared React application as an iOS app after PWA and Android foundations are proven.

## New tooling

```bash
npm install @capacitor/ios
npx cap add ios
```

Also required outside npm: macOS, Xcode, iOS SDK, signing configuration and an Apple Developer account for TestFlight/App Store distribution. CocoaPods may be required by the selected Capacitor/plugin setup.

## Requirements and acceptance criteria

- Capacitor core, CLI and iOS packages are installed, `capacitor.config.ts` is present, and `npx cap add ios` generated the iOS project.
- `xcodebuild` is present, but signing configuration, CocoaPods/plugin state and device/TestFlight validation are not available for safe completion here.
- Test Safari/WebView differences, safe areas, keyboard behavior and lifecycle interruptions.
- Test offline startup, local persistence, reconnect and pending operations.
- Document privacy declarations and platform permissions.
- No iOS-only frontend is created.