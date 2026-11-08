# Phase 16 — Optional Native Features

## Purpose

Add native capabilities only when a confirmed product requirement justifies platform permissions and maintenance.

## Candidates

| Capability | Candidate package | Gate |
|---|---|---|
| Camera | `@capacitor/camera` | Confirmed photo workflow |
| Filesystem | `@capacitor/filesystem` | Media/storage requirement |
| Share | `@capacitor/share` | Confirmed sharing workflow |
| Geolocation | `@capacitor/geolocation` | Confirmed location requirement |
| Push | `@capacitor/push-notifications` | Native push requirement |

No candidate is installed by this planning task. Each plugin requires a separate privacy, permission, storage and fallback review.

## Acceptance criteria

- A documented use case exists before installation.
- Web/PWA fallback behavior is defined.
- Permissions are minimal and revocable.