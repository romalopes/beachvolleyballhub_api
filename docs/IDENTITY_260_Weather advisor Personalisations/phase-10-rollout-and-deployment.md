# Phase 10 — Documentation, Rollout, and Deployment

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Release notes, deployment order, smoke tests, rollback

---

## 1. Deliverables

- Phase reports `phase-0` … `phase-9` in this directory
- This document (rollout + operations)
- Original plan updated to **IMPLEMENTED** with the file inventory and
  verification commands

## 2. Deployment Order

1. **Migration first** — `20261119000001_add_weather_advisor_personalization`
   is purely additive: two nullable-free JSONB columns with `{}` defaults on
   `weather_advisor_preferences`, plus the new
   `weather_advisor_location_preferences` table with a unique
   `(account_id, location_id)` index. Old rows keep working (empty JSON →
   normalized defaults at read time).
2. **Backend** — deploy the advisor/controller changes; existing callers
   (weather shares, `WeatherApi`) are unaffected because new `.assess`
   arguments are optional.
3. **Frontend** — deploy the extended settings UI; old frontends against the
   new backend still work (weights-only PATCH is valid).

## 3. Smoke Tests

1. Guest `GET /api/v1/weather` → default-weight score
2. Signed-in user, no saved prefs → `GET /weather_advisor_preference`
   materializes defaults incl. full conditions/directions
3. PATCH with modified wind thresholds (e.g. 10/15/35) + `NE => "bad"` →
   re-GET returns persisted values; next weather request reflects them
4. PATCH invalid value → 422 with message, prior values intact
5. DELETE → defaults restored, row gone
6. Two accounts, same coordinates, different preferences → different scores,
   no leakage
7. `/account#weather-advisor-preferences` deep link scrolls + focuses
8. Mobile layout: collapsible sections render and save

## 4. Monitoring

- Rails logs: watch for `Unpermitted parameters` (would indicate a payload
  shape change), validation 422 rates, and `WeatherApi` provider errors
- Sentry: `ArgumentError` from advisor (should be none after Phase 9 fixes)
- Score distribution shift after rollout is expected only for users who
  save preferences; guests must be unchanged

## 5. Rollback

- Preferences data is never deleted; rollback = revert code, keep schema
- Backend-only rollback: old advisor ignores the new arguments; stored
  JSONB simply goes unused until re-deploy
- Frontend rollback: weights-only UI continues to function against the
  extended API (extra keys in responses are ignored by old clients)
- Emergency scoring disable: pass no personalization args in the weather
  controller (one-line change) — saved settings remain intact

## 6. Known Limitations

- Beach-specific overrides currently cover wind direction only (per plan);
  condition thresholds remain account-wide
- Beach override management is backend/model-complete; the dedicated
  per-beach selector UI rides the existing location pickers and can be
  surfaced incrementally
- No feature-flag system was introduced (per plan guidance)