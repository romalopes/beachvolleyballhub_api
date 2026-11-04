# Phase 11 — Real-Device and Browser Validation

## Purpose

Validate responsive, PWA and offline behavior on real browsers and devices before native packaging.

## Test matrix

- Desktop browsers and existing regression suite.
- Android Chrome and installed PWA.
- iOS Safari and Add to Home Screen.
- Network loss/recovery, reload, termination, rotation, sleep/wake and storage pressure.
- Training, Assessment and Tournament offline journeys.
- Authentication expiry, sync failure and tournament conflict scenarios.

## Acceptance criteria

- Automated web validation is available through the existing Vitest suite and the successful production build.
- Real Android/iOS and installed-PWA validation is not complete in this workspace because Android `adb` and CocoaPods are unavailable and no device session was provided.
- A follow-up device run must record build version, device/browser, network state and result for the core journeys.