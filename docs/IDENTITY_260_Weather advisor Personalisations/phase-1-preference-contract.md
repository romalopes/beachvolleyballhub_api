# Phase 1 — Preference Contract and Scoring Specification

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Contract definition for Weather Advisor personalization

---

## 1. Final Preference Contract

### Weight Fields (unchanged from existing)
```json
{
  "wind_weight": 40,
  "temperature_weight": 20,
  "rain_weight": 25,
  "uv_weight": 5,
  "humidity_weight": 10
}
```
- All weights are integers 0-100
- Must sum to 100
- Zero weight is valid (factor excluded from score)

### Condition Fields (new)
```json
{
  "conditions": {
    "temperature": {
      "min_c": 5.0,
      "ideal_min_c": 17.0,
      "ideal_max_c": 28.0,
      "max_c": 40.0
    },
    "wind": {
      "ideal_max_kph": 10.0,
      "comfortable_max_kph": 20.0,
      "high_kph": 40.0
    },
    "rain": {
      "preferred_max_percent": 20.0,
      "comfortable_max_percent": 40.0,
      "high_percent": 80.0
    },
    "uv": {
      "preferred_max": 3.0,
      "comfortable_max": 6.0,
      "high": 10.0
    },
    "humidity": {
      "preferred_max_percent": 60.0,
      "comfortable_max_percent": 70.0,
      "high_percent": 90.0
    }
  }
}
```
- All values are numeric (float)
- Temperature: min_c < ideal_min_c ≤ ideal_max_c < max_c
- Wind: ideal_max_kph ≤ comfortable_max_kph ≤ high_kph
- Rain/UV/Humidity: preferred_max ≤ comfortable_max ≤ high

### Wind Direction Fields (new)
```json
{
  "wind_direction_preferences": {
    "N": "neutral",
    "NE": "neutral",
    "E": "neutral",
    "SE": "neutral",
    "S": "neutral",
    "SW": "neutral",
    "W": "neutral",
    "NW": "neutral"
  }
}
```
- Keys: 8 compass directions (N, NE, E, SE, S, SW, W, NW)
- Values: "neutral" (0), "bad" (-10), "very_bad" (-20)
- Direction penalties only reduce wind score, never increase
- Missing directions default to "neutral"

## 2. Validation Rules

### Weight Validation
- Each weight: integer 0-100
- Sum of all five weights = 100
- Reject on any violation with clear error message

### Condition Validation
- All values must be finite numbers
- Temperature: min_c < max_c, ideal_min_c ≤ ideal_max_c
- Wind: ideal_max_kph ≤ comfortable_max_kph ≤ high_kph
- Rain/UV/Humidity: preferred_max ≤ comfortable_max ≤ high

### Direction Validation
- Only 8 valid direction keys allowed
- Only 3 valid preference values allowed
- Reject unknown directions or values

## 3. Default Behavior

When no preference record exists or fields are empty:
- Weights: 40/20/25/5/10 (wind/temperature/rain/uv/humidity)
- Conditions: Hard-coded defaults matching current advisor behavior
- Directions: All "neutral"

## 4. Partial Update Behavior

- PATCH accepts any subset of fields
- Unprovided fields retain current values
- Validation runs on complete resulting object

## 5. Missing Value Behavior

- Empty conditions object → use all defaults
- Empty directions object → all "neutral"
- Individual missing condition fields → use default for that field
- Individual missing directions → "neutral" for that direction

## 6. Backward Compatibility

Existing calls must continue to work:
```ruby
Weather::VolleyballAdvisor.assess(current: current, rain_chance_percent: rain)
Weather::VolleyballAdvisor.assess(current: current, weights: weights)
```

New optional parameters:
```ruby
Weather::VolleyballAdvisor.assess(
  current: current,
  rain_chance_percent: rain,
  weights: weights,
  conditions: conditions,
  wind_direction_preferences: general,
  beach_wind_direction_preferences: beach
)
```

## 7. Scoring Specification

### Temperature Score (using feels_like_c first)
- ≤ min_c: 15
- min_c to ideal_min_c: linear 15→100
- ideal_min_c to ideal_max_c: 100
- ideal_max_c to max_c: linear 100→20
- > max_c: 20

### Wind Score
- ≤ ideal_max_kph: 100
- ≤ comfortable_max_kph: 85
- ≤ 30 kph: 65
- ≤ high_kph: 40
- > high_kph: 15
- Gust penalty: -10 if gust - wind > 15
- Direction penalty: -10 (bad) or -20 (very_bad) applied after base score
- Clamped to 0-100

### Rain Score
- ≤ preferred_max_percent: 100
- ≤ comfortable_max_percent: 80
- ≤ 60%: 55
- ≤ high_percent: 30
- > high_percent: 10
- Precipitation fallback when chance unavailable

### UV Score
- < preferred_max: 100
- < comfortable_max: 90
- < 8: 70
- ≤ high: 45
- > high: 25

### Humidity Score
- ≤ preferred_max_percent: 100
- ≤ comfortable_max_percent: 90
- ≤ 80%: 75
- ≤ high_percent: 50
- > high_percent: 25

### Final Score Calculation
- Each factor scored 0-100 or nil (missing)
- Factors with nil score or weight=0 excluded
- Remaining weights renormalized
- Weighted average rounded to integer
- No available factors → score: nil, label: "Unknown"

### Warnings (independent of weights and conditions)
- Wind > 40 kph or gust > 40 kph
- Feels-like ≥ 40°C
- Rain chance > 80%
- UV index > 10

## 8. Files Created/Modified

- `app/services/weather/advisor_preferences.rb` - Central contract module
- `app/services/weather/direction_preference_resolver.rb` - Direction resolution
- `app/models/weather_advisor_preference.rb` - Extended with conditions/directions
- `app/models/weather_advisor_location_preference.rb` - Beach-specific directions
- `db/migrate/20261119000001_add_weather_advisor_personalization.rb` - Schema

## 9. Test Coverage

- Model validations for all new fields
- Normalization functions
- Direction resolution with beach overrides
- Default behavior preservation
- Backward compatibility of `.assess` method