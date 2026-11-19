# Phase 6 — Frontend Condition Settings

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Account-page UI for condition thresholds

---

## 1. Type Updates (`src/api.ts`)

```typescript
export interface WeatherAdvisorConditions {
  temperature: { min_c: number; ideal_min_c: number; ideal_max_c: number; max_c: number };
  wind: { ideal_max_kph: number; comfortable_max_kph: number; high_kph: number };
  rain: { preferred_max_percent: number; comfortable_max_percent: number; high_percent: number };
  uv: { preferred_max: number; comfortable_max: number; high: number };
  humidity: { preferred_max_percent: number; comfortable_max_percent: number; high_percent: number };
}

export interface WeatherAdvisorPreference {
  wind_weight: number;
  temperature_weight: number;
  rain_weight: number;
  uv_weight: number;
  humidity_weight: number;
  conditions: WeatherAdvisorConditions;
  wind_direction_preferences: WeatherDirectionPreferences;
}
```

## 2. Utility Updates (`src/utils/weatherAdvisorPreferences.ts`)

- `DEFAULT_WEATHER_ADVISOR_CONDITIONS` — mirrors backend defaults (5 / 17 / 28 / 40 °C, 10 / 20 / 40 kph, 20 / 40 / 80 %, 3 / 6 / 10 UV, 60 / 70 / 90 %)
- `DEFAULT_WEATHER_DIRECTION_PREFERENCES` — all eight directions `"neutral"`
- `DEFAULT_WEATHER_ADVISOR_PREFERENCE` — extended with both new objects
- `normalizeConditions()` — merges partial user values over defaults, per-factor (explicit per-factor branches to keep TypeScript happy with the heterogeneous field shapes)
- `weatherPreferencesEqual()` — full-preference dirty check (weights + JSON-serialized conditions + JSON-serialized directions)

## 3. Component Updates (`WeatherAdvisorPreferences.tsx`)

### New collapsible sections per factor (`<details>`):
| Factor | Fields | Units | Step |
|---|---|---|---|
| Temperature | min / ideal min / ideal max / max | °C | 1 |
| Wind | ideal max / comfortable max / high | kph | 1 |
| Rain | preferred / comfortable / high | % | 5 |
| UV | preferred / comfortable / high | — | 1 |
| Humidity | preferred / comfortable / high | % | 5 |

Each field: labelled `<input type="number">` with `id`, `min=0`, `step`,
`disabled` while saving — keyboard accessible and screen-reader labelled.

### Handlers:
- `changeCondition(factor, field, value)` — spreads draft, merges via `normalizeConditions`
- `changeDirection(direction, value)` — spreads `wind_direction_preferences`
- Dirty state switched from `weatherWeightsEqual` to `weatherPreferencesEqual` so condition/direction edits enable Save/Discard

### Save/Reset flow (unchanged semantics, new payload):
- Save → `api.updateWeatherAdvisorPreference(draft)` sends the complete object
- Backend echoes normalized values → `setSaved`/`setDraft` with identical objects → dirty clears
- Reset → `api.resetWeatherAdvisorPreference()` → full default shape
- Refresh event `WEATHER_PREFERENCE_CHANGED_EVENT` broadcast on both

## 4. Tests (`WeatherAdvisorPreferences.test.tsx`)

- Mocks return the full default shape (conditions + directions)
- Save assertion relaxed to `expect.objectContaining({...weights})` so the added fields don't break weight rebalance assertions
- All 5 tests pass: load/explanations, rebalance+save+broadcast, discard+reset, API error keeps draft, hash deep-link scroll/focus

## 5. Files Modified

- `src/api.ts`
- `src/utils/weatherAdvisorPreferences.ts`
- `src/components/weather/WeatherAdvisorPreferences.tsx`
- `src/components/weather/WeatherAdvisorPreferences.test.tsx`
- `src/api.test.ts` (preference fixture extended with conditions/directions)