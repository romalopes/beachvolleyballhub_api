# Phase 2 — Persistence and Validation

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Database schema, models, and validations for personalization fields

---

## 1. Database Migration

**File:** `db/migrate/20261119000001_add_weather_advisor_personalization.rb`

```ruby
class AddWeatherAdvisorPersonalization < ActiveRecord::Migration[8.1]
  def change
    add_column :weather_advisor_preferences, :conditions, :jsonb, null: false, default: {}
    add_column :weather_advisor_preferences, :wind_direction_preferences, :jsonb, null: false, default: {}

    create_table :weather_advisor_location_preferences do |t|
      t.references :account, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.jsonb :wind_direction_preferences, null: false, default: {}
      t.timestamps
    end
    add_index :weather_advisor_location_preferences, %i[account_id location_id], unique: true,
              name: "index_weather_advisor_location_preferences_unique"
  end
end
```

### Changes:
- Added `conditions` JSONB column to `weather_advisor_preferences` (default: {})
- Added `wind_direction_preferences` JSONB column to `weather_advisor_preferences` (default: {})
- Created `weather_advisor_location_preferences` table for beach-specific direction overrides
- Unique index on (account_id, location_id)
- Foreign keys to accounts and locations

---

## 2. Model Updates

### `app/models/weather_advisor_preference.rb`

**New associations:**
```ruby
has_many :weather_advisor_location_preferences, dependent: :destroy
```

**New validations:**
```ruby
validate :conditions_are_valid
validate :directions_are_valid
```

**New methods:**
```ruby
def effective_conditions
  Weather::AdvisorPreferences.normalize_conditions(conditions)
end

def effective_wind_direction_preferences
  Weather::AdvisorPreferences.normalize_directions(wind_direction_preferences)
end
```

**Condition validation:**
- All values must be numeric and finite
- Temperature: min_c < max_c, ideal_min_c ≤ ideal_max_c

**Direction validation:**
- Only 8 valid directions (N, NE, E, SE, S, SW, W, NW)
- Only 3 valid values (neutral, bad, very_bad)

### `app/models/weather_advisor_location_preference.rb`

New model for beach-specific wind direction overrides:
- Belongs to account and location
- Validates account/location uniqueness
- Validates direction keys and values
- `normalized_preferences` method returns merged defaults

### `app/models/account.rb`

Added association:
```ruby
has_many :weather_advisor_location_preferences, dependent: :destroy
```

### `app/models/location.rb`

Added association:
```ruby
has_many :weather_advisor_location_preferences, dependent: :destroy
```

---

## 3. Centralized Preference Module

**File:** `app/services/weather/advisor_preferences.rb`

Contains:
- `DIRECTIONS` - 8 compass directions
- `DIRECTION_VALUES` - neutral, bad, very_bad
- `DIRECTION_PENALTIES` - 0, -10, -20
- `CONDITIONS` - Default thresholds for all 5 factors
- `normalize_conditions()` - Merge user settings with defaults
- `normalize_directions()` - Merge user directions with defaults
- `direction_for()` - Resolve beach override → general → neutral
- `compass_direction()` - Convert degrees to compass direction

---

## 4. Direction Preference Resolver

**File:** `app/services/weather/direction_preference_resolver.rb`

Simple service for:
- `resolve(direction:, general:, beach:)` - Returns effective preference
- `penalty(preference)` - Returns numeric penalty (0, -10, -20)

---

## 5. Test Coverage

### `test/models/weather_advisor_preference_test.rb`
- Defaults produce documented distribution
- Valid custom distributions including boundaries
- Rejects weights outside 0-100 range
- Rejects non-integer weights
- Rejects totals other than 100
- Missing weight invalid
- Uniqueness per account
- Database constraints (unique, range, sum)
- Account destruction cascades
- **New:** Condition validation (bounds, types, temperature logic)
- **New:** Direction validation (keys, values)

### `test/models/weather_advisor_location_preference_test.rb`
- Valid direction preferences
- Invalid direction keys rejected
- Invalid preference values rejected
- Account/location uniqueness
- Normalized preferences merge with defaults
- Explicit neutral overrides

---

## 6. Key Design Decisions

1. **Additive migration** - No existing data touched, defaults handle backward compatibility
2. **JSONB columns** - Flexible schema for conditions/directions, supports partial updates
3. **Centralized defaults** - Single source of truth in `AdvisorPreferences` module
4. **Beach overrides separate table** - Avoids sparse columns, clear ownership
5. **Normalization on read** - `effective_conditions`/`effective_wind_direction_preferences` always return complete merged settings
6. **No direction bonus** - Penalties only (0, -10, -20), never positive