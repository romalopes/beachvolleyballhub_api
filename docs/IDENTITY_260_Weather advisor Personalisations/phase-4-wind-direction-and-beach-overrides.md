# Phase 4 — Wind Direction Mapping, Penalties, and Beach Overrides

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Direction preference resolution and beach-specific overrides

---

## 1. Direction Preference Resolver

**File:** `app/services/weather/direction_preference_resolver.rb`

```ruby
module Weather
  class DirectionPreferenceResolver
    def self.resolve(direction:, general:, beach: nil)
      AdvisorPreferences.direction_for(direction: direction, beach_preferences: beach, general_preferences: general)
    end

    def self.penalty(preference)
      AdvisorPreferences::DIRECTION_PENALTIES.fetch(preference.to_s, 0)
    end
  end
end
```

### Responsibilities:
- Resolve effective direction preference (beach → general → neutral)
- Return numeric penalty for a preference string

---

## 2. Compass Direction Mapping

**File:** `app/services/weather/advisor_preferences.rb`

### `compass_direction(degrees)`:
```ruby
DIRECTIONS = %w[N NE E SE S SW W NW].freeze

def compass_direction(degrees)
  value = Float(degrees, exception: false)
  return nil unless value&.finite? && value >= 0 && value <= 360
  return "N" if value == 360
  DIRECTIONS[((value + 22.5) / 45).floor % 8]
end
```

### 8-Point Compass Boundaries:
| Direction | Degrees |
|-----------|---------|
| N | 337.5 - 22.5 |
| NE | 22.5 - 67.5 |
| E | 67.5 - 112.5 |
| SE | 112.5 - 157.5 |
| S | 157.5 - 202.5 |
| SW | 202.5 - 247.5 |
| W | 247.5 - 292.5 |
| NW | 292.5 - 337.5 |

- Boundary at 22.5° offsets (centered on cardinal directions)
- 360° maps to N
- Invalid/NaN/out-of-range → nil (no penalty)

---

## 3. Preference Resolution Logic

### `direction_for(direction:, beach_preferences:, general_preferences:)`:

```ruby
def direction_for(direction:, beach_preferences:, general_preferences:)
  direction = direction.to_s.upcase
  return "neutral" unless DIRECTIONS.include?(direction)

  beach = normalize_directions(beach_preferences)
  general = normalize_directions(general_preferences)

  # Check for explicit beach override (including neutral)
  if beach_preferences.respond_to?(:key?) &&
     (beach_preferences.key?(direction) || beach_preferences.key?(direction.to_sym))
    value = beach[direction]
    return value if DIRECTION_VALUES.include?(value)
  end

  general.fetch(direction, "neutral")
end
```

### Resolution Order:
1. **Beach override** - If account has a beach-specific preference for this direction (including explicit "neutral")
2. **General preference** - Account-level direction preference
3. **Neutral** - Default if nothing configured

### Explicit Neutral Override:
- Beach setting `{"NE": "neutral"}` with general `{"NE": "bad"}` → effective "neutral"
- This allows users to cancel a general "bad" preference for a specific beach
- Distinguishes "no override" from "explicit neutral"

---

## 4. Beach-Specific Model

**File:** `app/models/weather_advisor_location_preference.rb`

```ruby
class WeatherAdvisorLocationPreference < ApplicationRecord
  belongs_to :account
  belongs_to :location

  validates :account_id, uniqueness: { scope: :location_id }
  validate :valid_direction_preferences

  def normalized_preferences
    Weather::AdvisorPreferences.normalize_directions(wind_direction_preferences)
  end
end
```

### Schema:
```ruby
create_table :weather_advisor_location_preferences do |t|
  t.references :account, null: false, foreign_key: true
  t.references :location, null: false, foreign_key: true
  t.jsonb :wind_direction_preferences, null: false, default: {}
  t.timestamps
end
add_index :weather_advisor_location_preferences, %i[account_id location_id], unique: true
```

### Features:
- One record per account/beach combination
- Only stores direction preferences (conditions remain account-level)
- Validates direction keys and values
- `normalized_preferences` merges with defaults

---

## 5. Integration with Advisor

**In `Weather::VolleyballAdvisor`:**

```ruby
direction = @current[:wind_direction] || @current["wind_direction"]
direction ||= AdvisorPreferences.compass_direction(@current[:wind_degree] || @current["wind_degree"])

preference = DirectionPreferenceResolver.resolve(
  direction:, general: @general_directions, beach: @beach_directions
)

(base + DirectionPreferenceResolver.penalty(preference)).clamp(0, 100)
```

### Data Flow:
1. Get wind direction from WeatherAPI (`wind_direction` string or `wind_degree` number)
2. Convert degrees to compass if needed
3. Resolve effective preference (beach → general → neutral)
4. Apply penalty (-10 or -20) to base wind score
5. Clamp result to 0-100

---

## 6. Authorization

- Any authenticated account can create/manage their own beach preferences
- No location admin rights required (preference is personal, not administrative)
- Account can only access their own beach preferences
- Standard `ensure_authenticated_account` before_action

---

## 7. Test Coverage

**File:** `test/services/weather/direction_preference_resolver_test.rb`

- All 8 compass directions mapped correctly
- Degree conversion at boundaries
- Invalid degree handling (nil, NaN, out of range)
- Neutral/good/bad/very_bad preferences
- General preference fallback
- Beach override precedence
- Explicit beach neutral cancels general
- No direction data → neutral
- No configured preferences → neutral
- Account isolation

**File:** `test/models/weather_advisor_location_preference_test.rb`

- Valid direction preferences accepted
- Invalid direction keys rejected
- Invalid preference values rejected
- Account/location uniqueness enforced
- Normalized preferences merge with defaults
- Explicit neutral in beach preferences

**File:** `test/models/weather_advisor_preference_test.rb` (extended)

- Direction validation (keys, values)
- Effective wind direction preferences method