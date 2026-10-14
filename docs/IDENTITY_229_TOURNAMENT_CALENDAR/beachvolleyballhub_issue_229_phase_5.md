## 7. Phase 5 — Frontend types, API client and reusable UI

Extend existing `src/api.ts` rather than using a parallel HTTP client. Add types for Tournament, Division, Participation, WatchLink, options, filters and pagination. Reuse auth/error handling, token/private gate and `normalizePaginatedResponse`. Build reusable tournament cards, badges, date formatting, division chips, filter state and loading/error/empty UI. Verify actual current file paths in Phase 0.

**AI prompt — frontend foundation**

In beachvolleyballhub_frontend, inspect current src/api.ts, types, router, auth context, calendar utilities and design system. Add typed tournament API methods, response normalization, date/timezone helpers, reusable tournament cards and division badges. Preserve all existing TrainingCalendar behavior and API conventions. Add Vitest/Testing Library coverage and mocked API fixtures. Do not build full pages yet. Do not invent components that already exist.

**Gate:** frontend build and unit tests pass; types cover Phase 4 API.