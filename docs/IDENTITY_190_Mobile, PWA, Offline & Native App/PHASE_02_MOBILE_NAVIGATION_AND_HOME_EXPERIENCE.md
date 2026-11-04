# Phase 02 — Mobile Navigation and Home Experience

## Purpose

Make the existing application usable on phones without breaking desktop routes, content or permissions.

## Requirements

- Preserve the current Home content and visual identity; reflow rather than replace it.
- Define mobile bottom navigation: **Drills, Training, Tournaments, Assessments, Analysis**.
- Keep the header logo as the Home action.
- Put account, organizations, coaches, players, locations, notifications and administration in the header/drawer where permitted.
- Use responsive CSS and touch targets; do not use viewport detection as authorization.

## Acceptance criteria
- Implemented the mobile status/header and bottom navigation in `src/App.tsx`, `src/components/MobileBottomNav.tsx` and `src/App.css`.
- Existing desktop routes/sidebar remain in place; the new navigation is limited to the mobile breakpoint.
- Five primary destinations are reachable: Drills, Training, Tournaments, Assessments and Analysis.
- Home was not replaced, and route visibility remains controlled by the existing route/authentication model.
- Navigation visibility follows server-provided permissions.