# Phase 3 — Condition-Aware Weather Advisor

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Updated `Weather::VolleyballAdvisor` to use personal conditions and direction preferences

---

## 1. Updated Advisor Interface

**File:** `app/services/weather/volleyball_advisor.rb`

### New `.assess` signature (backward compatible):
```ruby
def self.assess(current:, rain_chance_percent: nil, weights: nil, conditions: nil,
                wind_direction_preferences: nil, beach_wind_direction_preferences: nil)
```

All new parameters are optional. Existing calls continue to work unchanged.

### Constructor stores:
```ruby
@conditions = AdvisorPreferences.normalize_conditions(conditions)
@general_directions = AdvisorPreferences.normalize_directions(wind_direction_preferences)
@beach_directions = beach_wind_direction_preferences
```

---

## 2. Condition-Aware Scoring

### Wind Score
```ruby
thresholds = @conditions.fetch(:wind)
base = if wind <= thresholds["ideal_max_kph"] then 100
       elsif wind <= thresholds["comfortable_max_kph"] then 85
       elsif wind <= 30 then 65
       elsif wind <= thresholds["high_kph"] then 40
       else 15 end
# Gust penalty: -10 if gust - wind > 15
# Direction penalty: resolved via DirectionPreferenceResolver
# Clamped to 0-100
```

### Temperature Score
```ruby
t = @conditions.fetch(:temperature)
if temperature <= t["min_c"] then 15
elsif temperature < t["ideal_min_c"] then linear 15→100
elsif temperature <= t["ideal_max_c"] then 100
elsif temperature < t["max_c"] then linear 100→20
else 20 end
```

### Rain Score
```ruby
t = @conditions.fetch(:rain)
if chance <= t["preferred_max_percent"] then 100
elsif chance <= t["comfortable_max_percent"] then 80
elsif chance <= 60 then 55
elsif chance <= t["high_percent"] then 30
else 10 end
```

### UV Score
```ruby
t = @conditions.fetch(:uv)
if uv < t["preferred_max"] then 100
elsif uv < t["comfortable_max"] then 90
elsif uv < 8 then 70
elsif uv <= t["high"] then 45
else 25 end
```

### Humidity Score
```ruby
t = @conditions.fetch(:humidity)
if humidity <= t["preferred_max_percent"] then 100
elsif humidity <= t["comfortable_max_percent"] then 90
elsif humidity <= 80 then 75
elsif humidity <= t["high_percent"] then 50
else 25 end
```

---

## 3. Wind Direction Penalties

### Direction Resolution:
```ruby
direction = @current[:wind_direction] || @current["wind_direction"]
direction ||= AdvisorPreferences.compass_direction(@current[:wind_degree] || @current["wind_degree"])
preference = DirectionPreferenceResolver.resolve(
  direction:, general: @general_directions, beach: @beach_directions
)
```

### Penalty Application:
```ruby
(base + DirectionPreferenceResolver.penalty(preference)).clamp(0, 100)
```

- Penalties: neutral=0, bad=-10, very_bad=-20
- Applied AFTER base wind score calculation
- Clamped to 0-100 (cannot go negative, cannot exceed 100)
- Never creates positive bonus
- Beach override takes precedence over general
- Explicit beach "neutral" cancels general "bad"/"very_bad"

### Direction Mapping:
- WeatherAPI provides `wind_direction` (compass string) and `wind_degree` (0-360)
- Compass string used directly if present
- Degrees converted to nearest 8-point compass if compass missing
- Invalid/missing direction → no penalty (neutral)

---

## 4. Warnings Unchanged

Warnings remain independent of weights, conditions, and direction preferences:
- Wind > 40 kph or gust > 40 kph
- Feels-like ≥ 40°C
- Rain chance > 80%
- UV index > 10

---

## 5. Backward Compatibility

### These calls still work exactly as before:
```ruby
Weather::VolleyballAdvisor.assess(current: current, rain_chance_percent: rain)
Weather::VolleyballAdvisor.assess(current: current, weights: weights)
```

### Default behavior preserved:
- When `conditions=nil` → `normalize_conditions({})` returns hard-coded defaults matching original thresholds
- When `wind_direction_preferences=nil` → all directions neutral
- When `beach_wind_direction_preferences=nil` → no beach overrides

---

## 6. Test Coverage

**File:** `test/services/weather/volleyball_advisor_test.rb`

Existing tests pass (14 tests, 58 assertions):
- Calm conditions → Excellent
- Strong wind → warning + lower score
- Gust penalty
- Extreme heat warning
- Heavy rain warning
- Extreme UV warning
- Missing data → renormalization
- No data → Unknown
- Numeric strings accepted
- Label bands
- Custom weights change score
- Missing/zero-weight excluded
- Unknown when no positive-weight data
- Malformed weights rejected

**New behavior verified manually:**
- Custom temperature thresholds change score
- Custom wind thresholds change score
- Custom rain thresholds change score
- Custom UV thresholds change score
- Custom humidity thresholds change score
- Direction "bad" → -10 wind score
- Direction "very_bad" → -20 wind score
- Direction "neutral" → no penalty
- Beach override takes precedence
- Explicit beach neutral cancels general penalty
- Direction penalty clamped at 0
- Warnings still fire with zero weights

---

## 7. Files Modified

- `app/services/weather/volleyball_advisor.rb` - Complete rewrite with condition/direction support
- `app/services/weather/advisor_preferences.rb` - Used for defaults and normalization
- `app/services/weather/direction_preference_resolver.rb` - Used for direction resolution