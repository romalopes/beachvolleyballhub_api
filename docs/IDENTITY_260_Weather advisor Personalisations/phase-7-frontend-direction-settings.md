# Phase 7 — Frontend General and Beach Direction Settings

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Direction preference UI (general + beach overrides)

---

## 1. General Direction Preferences

In `WeatherAdvisorPreferences.tsx`, a collapsible "Wind direction preferences"
section renders one `<select>` per compass direction:

- Directions: `N NE E SE S SW W NW` (from `WeatherDirectionKey`)
- Values: `Neutral`, `Bad`, `Very bad` (from `WeatherDirectionValue`)
- Default: `neutral` for every direction
- Each select has an `id="direction-<DIR>"` label for accessibility

The section explains the semantics:
> Wind direction is where the wind comes FROM. Preferences only reduce the
> wind score. Neutral = no effect, Bad = -10, Very bad = -20. Cannot create
> positive bonuses.

## 2. Beach-Specific Overrides

`WeatherAdvisorLocationPreference` (backend) stores per-(account, location)
direction overrides. The general preferences panel covers the account-wide
surface; the beach override surface rides the same `wind_direction_preferences`
shape scoped to a location.

Resolution precedence (backend, Phase 4):
1. Beach override for the direction — **including explicit `neutral`**
2. General account preference
3. `neutral`

Explicit-neutral matters: a user who marks NE "bad" globally can mark NE
"neutral" for a sheltered beach, cancelling the general penalty there.

## 3. Type Support

`src/api.ts`:
```typescript
export type WeatherDirectionValue = "neutral" | "bad" | "very_bad";
export type WeatherDirectionKey = "N" | "NE" | "E" | "SE" | "S" | "SW" | "W" | "NW";
export interface WeatherDirectionPreferences {
  N?: WeatherDirectionValue; NE?: WeatherDirectionValue; /* ... */
}
```

`src/utils/weatherAdvisorPreferences.ts`:
- `DEFAULT_WEATHER_DIRECTION_PREFERENCES` (all neutral)
- `normalizeDirections()` filters to valid keys/values and fills defaults

## 4. Save Behavior

General directions ride the same PATCH payload as weights and conditions;
the backend echoes the normalized 8-direction map, so the UI always shows a
complete state and `weatherPreferencesEqual` clears the dirty flag after save.

## 5. Tests

- `api.test.ts` preference fixture includes all eight directions as `neutral`
- Component tests pass with the extended default preference
- Backend regression tests cover: persistence of `"NE" => "bad"`,
  `"SW" => "very_bad"`, untouched directions defaulting to neutral, and 422
  on invalid values such as `"unbearable"`