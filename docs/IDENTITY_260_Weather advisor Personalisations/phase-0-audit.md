# Phase 0 — Existing Implementation Audit and Baseline Tests

**Status:** Completed
**Date:** 2026-11-19
**Scope:** BeachVolleyballHub Rails API + React/Vite frontend

---

## 1. Current Weather Advisor Implementation

### File: `app/services/weather/volleyball_advisor.rb`

```ruby
WEIGHTS = {
  wind: 0.40,
  temperature: 0.20,
  rain: 0.25,
  uv: 0.05,
  humidity: 0.10
}.freeze

LABELS = [
  [85, "Excellent"],
  [70, "Good"],
  [50, "Fair"],
  [30, "Poor"],
  [0, "Unsuitable"]
].freeze
```

### Current Scoring Behavior

1. **Factor scores** (each 0–100):
   - **Wind**: Based on wind_kph with gust penalty
     - ≤ 10 kph → 100
     - ≤ 20 kph → 85
     - ≤ 30 kph → 65
     - ≤ 40 kph → 40
     - > 40 kph → 15
     - Gust penalty: -10 if gust - wind > 15
   - **Temperature**: Uses feels_like_c first, falls back to temperature_c
     - ≤ 10°C → 20
     - ≤ 18°C → 75
     - ≤ 28°C → 100
     - ≤ 32°C → 90
     - > 32°C → 30
   - **Rain**: Uses rain_chance_percent if available, else precipitation_mm fallback
     - 0% → 100
     - ≤ 20% → 95
     - ≤ 40% → 80
     - ≤ 60% → 60
     - ≤ 80% → 30
     - > 80% → 10
   - **UV**: Based on uv_index
     - < 3 → 100
     - < 6 → 90
     - < 8 → 70
     - ≤ 10 → 45
     - > 10 → 25
   - **Humidity**: Based on humidity_percent
     - ≤ 60% → 100
     - ≤ 70% → 90
     - ≤ 80% → 75
     - ≤ 90% → 50
     - > 90% → 25

2. **Missing data handling**: Missing factors are excluded, remaining weights renormalized
3. **Zero weight**: Valid, factor excluded from score
4. **No available factors**: Returns `score: nil`, `label: "Unknown"`

### Current Warnings (independent of weights and score)
- Wind warning: wind > 40 kph or gust > 40 kph
- Heat warning: feels_like ≥ 40°C
- Rain warning: rain_chance > 80%
- UV warning: uv_index > 10

---

## 2. Weather Provider (WeatherAPI.com)

### File: `app/services/weather_api.rb`

Returns normalized current, hourly, and daily data with:
- `wind_kph`, `wind_gust_kph`, `wind_degree`, `wind_direction` (compass: N, NE, E, SE, S, SW, W, NW)
- `temperature_c`, `feels_like_c`
- `humidity_percent`
- `uv_index`
- `precipitation_mm`
- `rain_chance_percent` (daily chance_of_rain, hourly chance_of_rain)
- `condition`, `condition_code`

---

## 3. Current Preference System

### File: `app/models/weather_advisor_preference.rb`

- Belongs to Account (unique per account)
- Five weight fields: `wind_weight`, `temperature_weight`, `rain_weight`, `uv_weight`, `humidity_weight`
- Defaults: 40/20/25/5/10 (sum = 100)
- Database constraints: each 0–100, sum = 100
- `has_one :weather_advisor_preference` on Account

### File: `app/controllers/api/v1/weather_advisor_preferences_controller.rb`

- `GET /api/v1/weather_advisor_preference` — show (creates defaults if missing)
- `PATCH /api/v1/weather_advisor_preference` — update (validates sum = 100)
- `DELETE /api/v1/weather_advisor_preference` — destroy (returns defaults)
- Authenticated only (cookie session)

### File: `app/controllers/api/v1/weather_controller.rb`

- `GET /api/v1/weather?lat=...&lon=...`
- Uses `current_preference&.weights` for personalized assessment
- Guest requests use default weights
- Hourly assessments also use personalized weights

---

## 4. Frontend Weather Preferences

### File: `src/components/weather/WeatherAdvisorPreferences.tsx`

- Five noUiSlider controls for weights
- Rebalance logic maintains 100% total
- Save, Discard, Reset to defaults
- Loading, error, success states
- Deep-link support via `/account#weather-advisor-preferences`

### File: `src/utils/weatherAdvisorPreferences.ts`

- `DEFAULT_WEATHER_ADVISOR_PREFERENCE` object
- `rebalanceWeatherWeights()` — maintains 100% sum
- `weatherWeightsEqual()` — dirty check

### File: `src/api.ts` (relevant parts)

```typescript
weatherAdvisorPreference: () => fetchAPI<WeatherAdvisorPreference>("/weather_advisor_preference"),
updateWeatherAdvisorPreference: (data) => postJSON<WeatherAdvisorPreference>("/weather_advisor_preference", { weather_advisor_preference: data }, "PATCH"),
resetWeatherAdvisorPreference: () => postJSON<WeatherAdvisorPreference>("/weather_advisor_preference", {}, "DELETE"),
```

### Type: `WeatherAdvisorPreference`

```typescript
export interface WeatherAdvisorPreference {
  wind_weight: number;
  temperature_weight: number;
  rain_weight: number;
  uv_weight: number;
  humidity_weight: number;
}
```

---

## 5. Location Model

### File: `app/models/location.rb`

- `has_many :weather_advisor_location_preferences` (to be added)
- Sluggable, geocoded, verifiable
- `usable_by?(account)` scope for authorization

---

## 6. Cache Behavior

### WeatherApi Cache Key

```ruby
cache_key = "weather/v4/#{latitude.round(2)},#{longitude.round(2)}/days-#{FORECAST_DAYS}"
```

**Risk:** Cache key does not include user preferences. If personalized assessments are cached, they would leak between users.

**Current behavior:** `WeatherApi.fetch_forecast` returns provider data + **default** volleyball assessment. The controller then re-assesses hourly data with user weights. This is safe for current behavior.

---

## 7. Existing Test Commands

### Backend
```bash
cd /Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub_api
bin/rails test test/services/weather/volleyball_advisor_test.rb
bin/rails test test/models/weather_advisor_preference_test.rb
bin/rails test test/controllers/api/v1/weather_advisor_preferences_controller_test.rb
bin/rails test test/controllers/api/v1/weather_controller_test.rb
```

### Frontend
```bash
cd /Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub
npm test
```

---

## 8. Risks Identified

1. **Cache isolation**: Must ensure personalized assessments are not cached in shared provider cache
2. **Backward compatibility**: All existing `.assess` callers must continue working
3. **Default preservation**: Default behavior must match exactly when no preferences are set
4. **Authorization**: Beach-specific preferences must not grant location admin rights
5. **Schema migration**: Additive JSON columns with non-null defaults required
6. **API contract**: Frontend type definitions must stay in sync with backend serialization
