# BeachVolleyballHub --- Weather Advisor Personalization

## Implementation Plan: Configurable Weather Conditions, Tolerances, and Wind Direction

**Status:** IMPLEMENTED (2026-11-19) - see completion note below\
**Scope:** Rails API + React/Vite frontend\
**Primary backend area:** `Weather::VolleyballAdvisor` (`advisor.rb`)\
**Project:** BeachVolleyballHub\
**Implementation principle:** Preserve the existing Weather Advisor
behavior and weight configuration, then add user-configurable condition
thresholds and optional wind-direction penalties.

---

## Implementation completion note (2026-11-19)

All phases were implemented and verified. Phase reports live alongside this
file as `phase-0-audit.md` through `phase-10-rollout-and-deployment.md`.

### Bugs found and fixed during final verification

1. **Strong parameters silently dropped nested objects.** The first
   controller implementation used `permit(:conditions, :wind_direction_preferences)`.
   Rails treats plain symbols as scalar permits and filters out nested
   hashes, so the API returned `200 OK` (weights saved) while logging
   `Unpermitted parameters: :conditions, :wind_direction_preferences` and
   discarding both objects. Fixed with the open-hash form:

   ```ruby
   params.require(:weather_advisor_preference).permit(
     *WeatherAdvisorPreference::WEIGHT_ATTRIBUTES,
     conditions: {},
     wind_direction_preferences: {}
   )
   ```

   Regression test: `update persists nested conditions and wind direction
   preferences` asserts every nested value reaches the database.

2. **Validation crash on non-numeric condition values.** The temperature
   ordering comparison ran even when a condition value was a non-numeric
   string, raising `ArgumentError: comparison of String with 40.0 failed`
   instead of returning a validation error. Fixed by collecting type errors
   first and running ordering comparisons only when every value is numeric.
   Regression test: `update rejects invalid nested condition values`.

### Final test status

- Backend weather suite: 39 runs, 149 assertions, 0 failures, 0 errors
- Frontend weather components: 22 tests passing
- Frontend build: `tsc -b && vite build` clean



---

## Implementation completion note (2026-11-19)

All phases were implemented and verified. Phase reports live alongside this
file as `phase-0-audit.md` through `phase-10-rollout-and-deployment.md`.

### Bugs found and fixed during final verification

1. **Strong parameters silently dropped nested objects.** The first
   controller implementation used `permit(:conditions, :wind_direction_preferences)`.
   Rails treats plain symbols as scalar permits and filters out nested
   hashes, so the API returned `200 OK` (weights saved) while logging
   `Unpermitted parameters: :conditions, :wind_direction_preferences` and
   discarding both objects. Fixed with the open-hash form:

   ```ruby
   params.require(:weather_advisor_preference).permit(
     *WeatherAdvisorPreference::WEIGHT_ATTRIBUTES,
     conditions: {},
     wind_direction_preferences: {}
   )
   ```

   Regression test: `update persists nested conditions and wind direction
   preferences` asserts every nested value reaches the database.

2. **Validation crash on non-numeric condition values.** The temperature
   ordering comparison ran even when a condition value was a non-numeric
   string, raising `ArgumentError: comparison of String with 40.0 failed`
   instead of returning a validation error. Fixed by collecting type errors
   first and running ordering comparisons only when every value is numeric.
   Regression test: `update rejects invalid nested condition values`.

### Final test status

- Backend weather suite: 39 runs, 149 assertions, 0 failures, 0 errors
- Frontend weather components: 22 tests passing
- Frontend build: `tsc -b && vite build` clean



------------------------------------------------------------------------

## 1. Objective

Improve the Weather Advisor so that its playability score reflects both:

1.  **How important each weather parameter is to the user** --- the
    existing weights.
2.  **What weather conditions the user personally considers acceptable**
    --- new configurable thresholds and tolerances.

Also introduce optional wind-direction preferences:

-   If the user does not configure wind direction, direction has no
    effect.
-   General wind-direction preferences apply to all beaches.
-   A user may configure overrides for a particular beach.
-   Direction preferences can only penalize the wind score. There are no
    positive wind-direction bonuses.

The result should remain understandable, backward-compatible, testable,
and straightforward to configure.

## 2. Product decisions and rules

These decisions are the agreed product requirements and should be
treated as implementation constraints.

### 2.1 Existing weights remain

The current weight configuration must be retained. Do not replace it
with condition thresholds.

Weights answer: **"How important is this factor compared with the
others?"**

Condition settings answer: **"What values do I personally find
comfortable or unacceptable?"**

Both affect the final recommendation, but they have different
responsibilities.

### 2.2 Configurable weather parameters

Allow the user to configure thresholds/tolerances for the weather
parameters already supported by the advisor. At minimum, review and
support the existing parameters such as:

-   Temperature
-   Wind speed
-   Rain / precipitation
-   UV
-   Humidity
-   Feels-like temperature, if currently scored independently

Do not introduce a new scored weather factor merely because it appears
in this plan. First inspect the existing implementation and provider
data.

Use meaningful thresholds for each parameter. Examples:

-   Temperature: minimum comfortable, ideal minimum, ideal maximum,
    maximum comfortable.
-   Wind speed: preferred/comfortable maximum and high/unplayable
    thresholds.
-   Rain: probability and/or precipitation amount thresholds, depending
    on the data already supplied by the provider.
-   UV: preferred maximum and high-UV threshold.
-   Humidity: preferred maximum and discomfort threshold.

The exact fields and defaults must be derived from the current advisor
implementation. Preserve current behavior as closely as possible when a
user has not customized anything.

### 2.3 Wind direction has three preference values only

The only supported wind-direction preferences are:

  Preference     Direction penalty
  ------------ -------------------
  Neutral                        0
  Bad                          -10
  Very bad                     -20

There is no `Good` or `Very good` option. Beach volleyball players do
not receive a positive score bonus because a wind direction is
considered favourable. Direction can leave the wind score unchanged or
make it worse.

These values are **illustrative score-point penalties on the wind
subscore**, not percentages and not direct deductions from the final
overall score. Confirm this interpretation in the implementation and
tests.

### 2.4 Eight compass directions

Use these eight direction keys:

-   N
-   NE
-   E
-   SE
-   S
-   SW
-   W
-   NW

All general directions default to `Neutral`.

A beach-specific preference is optional for each direction. If a
direction has no beach-specific override, it inherits the user's general
preference.

### 2.5 No court orientation or court mapping in this implementation

Do not implement:

-   Court GPS coordinates
-   Court bearing/orientation
-   Headwind/tailwind/crosswind geometry
-   Court groups or individual court records
-   Trigonometric wind-component calculations

The agreed approach is intentionally simpler: the user records their
practical knowledge, for example "E wind is bad in my area" or "SE wind
is very bad at Coogee".

A beach's normal geographic position is already used to obtain weather.
It does not need a court orientation for this feature.

### 2.6 Wind direction is optional

If wind direction is absent, invalid, or unavailable from the weather
provider:

-   Do not apply a directional penalty.
-   Continue calculating wind playability from wind speed and the
    existing wind-related inputs.
-   Do not treat missing direction as `Neutral` stored data; it means
    "no directional adjustment can be calculated for this forecast".

### 2.7 Preference precedence

For a given user, beach, and forecast direction:

1.  Use a beach-specific override if one exists.
2.  Otherwise use the user's general preference.
3.  Otherwise use `Neutral` (zero penalty).

Important: a beach-specific `Neutral` is an explicit override and must
override a general `Bad` or `Very bad` setting. Therefore, the data
model must distinguish: - no beach override (inherit), and - explicit
beach override of `Neutral` (penalty zero).

Do not implement precedence using a truthiness check that accidentally
treats `Neutral` as absent.

------------------------------------------------------------------------

## 3. Expected user experience

### 3.1 General Weather Advisor preferences

Extend the existing Weather Advisor preferences/settings UI. Do not
create a separate top-level settings area unless the current application
architecture requires it.

Suggested sections:

1.  **Weights** --- existing sliders and behavior.
2.  **Weather conditions** --- new thresholds/tolerances for each
    supported parameter.
3.  **Wind direction** --- optional general preferences for N, NE, E,
    SE, S, SW, W, NW.

Each direction should offer only: - Neutral - Bad - Very bad

All eight general directions should initially be Neutral. The UI should
make it clear that Neutral means no direction penalty.

### 3.2 Beach-specific preferences

From the relevant beach/location experience, allow the user to search
for or select a saved BeachVolleyballHub location and optionally
customize wind directions for that beach.

The beach settings should be concise:

-   Show the selected beach name.
-   Show the eight compass directions.
-   Allow Neutral, Bad, or Very bad.
-   Make it clear that unset directions inherit the general preferences.
-   Provide an action to clear/remove an override and return to
    inheritance.

Do not require users to configure a beach. The feature is optional.

### 3.3 Helpful explanatory copy

Suggested copy:

> Wind direction preferences are optional. Set directions that make
> playing conditions worse for you. Your general preferences apply to
> all beaches. You can customize individual beaches when local
> conditions are different.

For beach overrides:

> Only directions you change here override your general preferences.
> Leave a direction unset to inherit your general setting.

For missing forecast direction:

> Wind direction is unavailable for this forecast, so your direction
> preferences were not applied.

### 3.4 Mobile and desktop

The settings should work on desktop and mobile browsers and remain
usable in the existing PWA layout.

Prefer compact direction rows or a simple compass layout. Do not make
the compass graphic essential to operation; accessible text labels and
controls must remain available.

------------------------------------------------------------------------

## 4. Phase 0 --- Repository inspection and baseline

**Goal:** Understand the existing implementation before changing it.

### Backend inspection

Inspect:

-   `Weather::VolleyballAdvisor` and its `advisor.rb`.
-   Existing score calculation methods and thresholds.
-   Existing `WEIGHTS` configuration and where it is stored.
-   Existing account/user preference model, JSON settings, or related
    persistence.
-   Weather provider response mapping, especially wind direction units
    and semantics.
-   Existing location model and how a forecast is associated with a
    location.
-   API controllers, serializers, routes, authorization policies, and
    request specs for weather/preferences.
-   Existing tests for score calculation and weather recommendations.

### Frontend inspection

Inspect:

-   Existing Weather Advisor settings page/component.
-   Existing weight slider implementation (including the current
    `nouislider` integration, if still used).
-   API client/hooks and preference save/load flow.
-   Existing location search/selection UI.
-   Validation, loading, error, and success patterns.
-   Responsive/mobile patterns.

### Baseline documentation

Before changing behavior:

1.  Record the current default weights.
2.  Record every current parameter threshold and scoring curve.
3.  Record how missing provider values are handled.
4.  Record the current score range and final recommendation bands.
5.  Add or update characterization tests for representative current
    forecasts.

**Acceptance criteria**

-   The implementation team can explain the current score calculation
    end-to-end.
-   Existing defaults and recommendation behavior are documented.
-   No assumptions about model names, JSON columns, or API routes are
    made before repository inspection.

------------------------------------------------------------------------

## 5. Phase 1 --- Define the preference contract and scoring design

**Goal:** Agree on a stable structure between Rails, the frontend, and
the advisor.

### 5.1 Separate weights from conditions

Keep separate concepts in the preference contract.

Illustrative structure only:

``` json
{
  "weights": {
    "temperature": 25,
    "wind": 30,
    "rain": 20,
    "uv": 15,
    "humidity": 10
  },
  "conditions": {
    "temperature": {
      "min": 16,
      "ideal_min": 20,
      "ideal_max": 30,
      "max": 35
    },
    "wind": {
      "ideal_max": 15,
      "acceptable_max": 25,
      "unplayable": 40
    },
    "rain": {
      "max_probability": 20
    },
    "uv": {
      "preferred_max": 7
    },
    "humidity": {
      "preferred_max": 70,
      "max": 90
    }
  },
  "wind_direction_preferences": {
    "N": "neutral",
    "NE": "neutral",
    "E": "bad",
    "SE": "very_bad",
    "S": "neutral",
    "SW": "neutral",
    "W": "neutral",
    "NW": "neutral"
  }
}
```

This is an example contract, not a requirement to store exactly this
JSON. Adapt it to existing project conventions.

### 5.2 Choose the source of truth

Prefer the existing user/account weather preference persistence if it is
appropriate. Avoid creating a duplicate preference system.

Inspect whether preferences belong to: - a user, - an account, - or a
specific membership/profile.

Use the same ownership convention as the existing weight settings.
Ensure one user's settings cannot leak to another user in a shared
account context.

### 5.3 Define threshold semantics

For every parameter, document:

-   Unit (°C, km/h, %, UV index, etc.).
-   Lower/upper boundaries.
-   Ideal range, if relevant.
-   What happens between ideal and unacceptable values.
-   What happens outside the acceptable range.
-   Missing-value behavior.
-   Validation rules.

Use continuous scoring curves where practical, rather than abrupt jumps
at a single cutoff. Avoid changing the shape of the existing curve
unnecessarily; parameterize its thresholds first.

### 5.4 Define wind direction mapping

Weather providers commonly report wind direction in degrees as the
direction the wind is **coming from**. Verify the actual provider and
adapter semantics.

Map degrees to the nearest of eight compass directions using 45-degree
sectors:

  Direction     Centre bearing
  ----------- ----------------
  N                  0° / 360°
  NE                       45°
  E                        90°
  SE                      135°
  S                       180°
  SW                      225°
  W                       270°
  NW                      315°

Use sector boundaries halfway between centres. For example: - N: 337.5°
through 22.5°, wrapping around 360°. - NE: greater than 22.5° through
67.5°. - Continue in 45-degree sectors.

Normalize valid numeric bearings to the range 0--359.999... before
mapping. Reject nil, non-numeric, or out-of-range values according to
the provider adapter's established conventions; do not silently map
invalid data to North.

### 5.5 Define the scoring order

Recommended calculation:

1.  Calculate each weather parameter's base subscore using the user's
    configured conditions.
2.  For wind, calculate the normal wind-speed subscore first.
3.  Resolve the applicable direction preference (beach override, then
    general, then Neutral).
4.  Map preference to a direction penalty: Neutral = 0, Bad = -10, Very
    bad = -20.
5.  Apply the penalty to the wind subscore only.
6.  Clamp the adjusted wind subscore to the supported range (normally
    0--100).
7.  Apply the existing wind weight and calculate the weighted overall
    score using the existing normalization.
8.  Apply the existing final recommendation bands.

Example:

``` ruby
adjusted_wind_score = [
  [base_wind_score + direction_penalty, 0].max,
  100
].min
```

The exact score range and weighted aggregation must follow the current
advisor. If its wind subscore uses a different range, adapt the penalty
scale deliberately and document it.

**Do not subtract the direction penalty from the final overall score.**
Applying it to the wind subscore means the existing wind weight
continues to determine how important wind is to that user.

### 5.6 Avoid double-counting

Wind direction is not a new independent weighted parameter. It modifies
the existing wind score. Do not add a separate wind-direction weight.

**Acceptance criteria**

-   The contract distinguishes weights, conditions, and direction
    preferences.
-   Eight direction buckets and their boundaries are documented.
-   The scoring order and penalty semantics are explicit.
-   Missing direction and inheritance behavior are specified.

------------------------------------------------------------------------

## 6. Phase 2 --- Persist configurable weather conditions

**Goal:** Store each user's condition thresholds without breaking
existing weight preferences.

### Implementation tasks

1.  Reuse the current preference storage where appropriate.
2.  Add condition settings for each existing scored weather parameter.
3.  Provide defaults that reproduce the current advisor behavior as
    closely as possible.
4.  Keep existing weight values and their save/load behavior unchanged.
5.  Add strong server-side validation:
    -   Numeric values only.
    -   Valid units/ranges.
    -   Minimum must not exceed maximum.
    -   Ideal minimum must not exceed ideal maximum.
    -   Wind thresholds must be logically ordered.
    -   Percentages must remain within 0--100.
    -   UV thresholds must use the provider's expected UV scale.
6.  Define behavior for partial settings: omitted fields use defaults.
7.  Ensure old users with no condition configuration continue to receive
    valid results.
8.  Add migration/backfill only if required by the chosen persistence
    design.

### Defaults and backward compatibility

Do not invent new default thresholds that change the current user
experience. Extract the existing values from `advisor.rb` and use them
as the initial defaults.

If settings are stored in JSON: - Validate and normalize the JSON
through a dedicated service or model concern. - Avoid trusting arbitrary
client-supplied keys. - Keep a versioned/defaulted schema if that
matches project conventions. - Avoid writing a full default object over
existing saved values when updating only one field.

### Suggested backend organization

Adapt names to current code conventions. Potential responsibilities:

-   Preference model or settings object: persistence and validation.
-   Defaults/normalizer: fills missing values.
-   Advisor: pure scoring using supplied normalized preferences.
-   Serializer: returns effective preferences and units to the frontend.

Do not put database lookups, controller logic, or frontend-specific
behavior inside the scoring methods.

**Acceptance criteria**

-   A user can save and retrieve condition settings.
-   Existing weight settings remain intact.
-   Old users receive defaults equivalent to the existing behavior.
-   Invalid or contradictory settings are rejected with useful
    validation errors.
-   Tests cover partial settings and defaulting.

------------------------------------------------------------------------

## 7. Phase 3 --- Implement condition-aware scoring in `Weather::VolleyballAdvisor`

**Goal:** Make the advisor use personal thresholds rather than only
fixed constants.

### Implementation tasks

1.  Refactor the advisor so it receives normalized preferences
    explicitly.
2.  Keep weather input parsing separate from scoring.
3.  Replace hardcoded thresholds with values from the conditions
    configuration.
4.  Preserve existing scoring curve shapes unless a change is necessary
    to support configurable thresholds.
5.  Keep each parameter's score independently inspectable.
6.  Preserve existing weight normalization and final recommendation
    bands.
7.  Handle missing provider data using the existing behavior; do not
    treat missing data as ideal weather.
8.  Make the scoring methods deterministic and straightforward to unit
    test.

### Parameter-specific behavior

**Temperature** - Support user-defined minimum/maximum comfort
boundaries and ideal range if the current algorithm supports a range. -
Penalize colder/hotter conditions progressively. - Validate boundary
ordering.

**Wind speed** - Support personal preferred, acceptable, and
high/unplayable thresholds. - Preserve the existing wind score curve as
much as possible. - Direction penalty is added in a later phase.

**Rain** - Use the provider's available precipitation probability and/or
amount. - Do not conflate probability (%) with precipitation amount
(mm). - Allow the user to set tolerance for the actual metric being
scored. - Preserve existing handling when one rain metric is
unavailable.

**UV** - Use the provider's UV index scale. - Allow the user to choose
when UV begins to reduce playability and the threshold for severe
penalty. - Do not interpret UV index as a percentage.

**Humidity** - Allow personal discomfort thresholds. - Preserve any
existing interaction with feels-like temperature; avoid counting the
same effect twice without a deliberate design decision.

**Feels-like temperature** - If independently scored today, make its
thresholds configurable. - If it is only an input to another
calculation, do not create a duplicate score.

### Tests

For every supported parameter, test: - At/below lower boundary. - Inside
ideal range. - At ideal boundaries. - Between ideal and maximum. -
At/above maximum. - Missing value. - Default preferences. - Customized
preferences.

Also test two preference profiles against the same weather input and
confirm they can produce different parameter scores and recommendations.

**Acceptance criteria**

-   The same forecast can produce different scores for users with
    different tolerances.
-   Default settings reproduce the previous result within the agreed
    tolerance.
-   Weights still affect the final score exactly as before.
-   The advisor has no dependency on HTTP/controller/database concerns.

------------------------------------------------------------------------

## 8. Phase 4 --- Implement wind-direction preferences and beach overrides

**Goal:** Add optional directional penalties with general and
beach-specific preferences.

### 8.1 Persistence design

Use the existing preference ownership model for general directions.

For beach-specific overrides, use a user-to-location preference
structure consistent with existing location ownership and authorization
patterns.

Possible approaches, to choose after repository inspection:

**Option A --- JSON settings** - General eight-direction map stored in
the existing user/account preferences. - Beach override map stored in a
user-location preference record or an existing per-user location
settings structure.

**Option B --- normalized records** - A general preference record with
one row per direction, or a validated JSON map. - A beach-specific
preference record associated with user/account and Location, containing
the direction map.

Prefer the simplest design consistent with the current Rails
application. Do not create one database row per compass direction unless
there is a real querying or auditing requirement.

### 8.2 General preferences

-   Support exactly N, NE, E, SE, S, SW, W, NW.
-   Allowed values: `neutral`, `bad`, `very_bad`.
-   Default every direction to `neutral`.
-   Reject unknown directions and values.
-   Missing general settings resolve to Neutral.

### 8.3 Beach-specific overrides

-   Associate overrides with the correct user/account and existing
    `Location`.
-   A missing direction key means inherit the general preference.
-   An explicit `neutral` value means override the general preference
    with no penalty.
-   Provide a way to remove an override.
-   Do not create a new beach/location when the user is only selecting
    an existing one to customize.
-   Apply existing location visibility, status, and authorization rules.
-   Prevent users from reading or changing another user's private
    overrides.

### 8.4 Resolution service

Create a small, independently tested resolver. Conceptual example:

``` ruby
def preference_for(direction:, beach_preferences:, general_preferences:)
  if beach_preferences.key?(direction)
    beach_preferences.fetch(direction)
  else
    general_preferences.fetch(direction, "neutral")
  end
end
```

The implementation must distinguish an absent key from a key whose value
is `"neutral"`.

Then map the resolved preference:

``` ruby
DIRECTION_PENALTIES = {
  "neutral" => 0,
  "bad" => -10,
  "very_bad" => -20
}.freeze
```

Keep the mapping centralized rather than duplicating it in controllers,
serializers, and frontend code.

### 8.5 Wind direction conversion

-   Confirm whether the weather provider reports degrees or compass
    text.
-   Confirm direction is meteorological "wind coming from" direction.
-   Convert provider direction to one of the eight compass keys.
-   Use nearest-sector mapping with wraparound at North.
-   If direction is absent or invalid, do not apply any directional
    penalty.
-   Do not infer a direction from the beach location.

### 8.6 Applying the penalty

Apply the resolved direction penalty to the base wind subscore only:

``` ruby
wind_score = clamp(base_wind_score + direction_penalty, 0, 100)
```

Use the actual score range if it differs from 0--100.

Then continue through the existing weighted aggregation. Do not: - add a
new wind-direction weight, - apply the penalty to every parameter, -
deduct the modifier directly from the final overall score, - give
positive bonuses for any direction.

### 8.7 Worked examples

Assume the base wind subscore is 75/100 and the penalties are the agreed
values.

  Effective preference     Penalty   Adjusted wind score
  ---------------------- --------- ---------------------
  Neutral                        0                    75
  Bad                          -10                    65
  Very bad                     -20                    55

If the base wind score is 8, a Very bad direction produces 0 after
clamping, not a negative score.

**Acceptance criteria**

-   No configured direction preferences means no directional penalty.
-   General preferences apply to every beach.
-   Beach overrides take precedence over general settings.
-   Explicit beach Neutral overrides a general Bad/Very bad.
-   Unset beach direction inherits the general preference.
-   Invalid/missing forecast direction applies no penalty.
-   Direction penalties affect only the wind subscore.

------------------------------------------------------------------------

## 9. Phase 5 --- API endpoints and serialization

**Goal:** Expose preferences safely and consistently to the frontend.

Inspect current routes and preference endpoints first. Extend existing
endpoints where appropriate rather than adding redundant APIs.

### Required API capabilities

1.  Retrieve the current user's effective Weather Advisor settings:
    -   Existing weights.
    -   Effective condition thresholds.
    -   General wind-direction preferences.
2.  Update weights without overwriting conditions.
3.  Update conditions without overwriting weights.
4.  Retrieve general direction preferences.
5.  Update general direction preferences.
6.  Retrieve beach-specific overrides for a selected location.
7.  Create/update a beach override.
8.  Remove a beach override or an individual direction override.

The API may combine some of these operations if that follows existing
conventions.

### API requirements

-   Authenticate endpoints that read or mutate private preferences.
-   Authorize the user/account and location association.
-   Permit only the supported parameter keys, direction keys, and enum
    values.
-   Return validation errors in the project's standard format.
-   Avoid mass assignment of arbitrary JSON.
-   Avoid exposing another user's settings.
-   Ensure partial updates do not reset unrelated settings.
-   Include units and effective/default values so the UI can label
    controls correctly.

### Suggested response concept

``` json
{
  "weights": {},
  "conditions": {},
  "wind_direction_preferences": {
    "N": "neutral",
    "NE": "neutral",
    "E": "bad",
    "SE": "very_bad",
    "S": "neutral",
    "SW": "neutral",
    "W": "neutral",
    "NW": "neutral"
  },
  "beach_overrides": {
    "SE": "very_bad"
  }
}
```

Use the actual project serializer conventions and avoid returning
internal implementation details.

**Acceptance criteria**

-   API contract is documented.
-   Partial updates preserve unrelated settings.
-   Authorization and validation specs cover all mutation endpoints.
-   Frontend can distinguish inherited directions from explicit beach
    overrides.

------------------------------------------------------------------------

## 10. Phase 6 --- Frontend: configurable condition thresholds

**Goal:** Add clear controls to the existing Weather Advisor preferences
screen.

### Implementation tasks

1.  Keep the existing weights section and its behavior.
2.  Add a "Weather conditions" section.
3.  Add controls for every supported scored parameter.
4.  Use numeric inputs for precise threshold values.
5.  Use sliders only where they improve usability and remain precise
    enough.
6.  Display units next to values.
7.  Explain briefly what each threshold means.
8.  Show loading, saving, validation, and error states.
9.  Support reset-to-defaults, with confirmation if it overwrites custom
    settings.
10. Ensure settings persist after refresh and across devices.

### UI guidance

Use progressive disclosure: - Show the main threshold controls first. -
Put advanced or less commonly changed values in collapsible sections if
the screen becomes too long. - Avoid a separate page for every
parameter. - Keep mobile controls easy to operate.

### Frontend validation

Mirror server-side validation for immediate feedback, but the server
remains authoritative.

Examples: - Minimum temperature must be lower than maximum
temperature. - Ideal minimum must not exceed ideal maximum. - Wind
thresholds must be ordered. - Probability must be 0--100. - UV and
humidity must use correct units/ranges.

**Acceptance criteria**

-   Existing weight controls still work.
-   User can edit and save condition thresholds.
-   Values display correct units.
-   Validation messages are understandable.
-   Settings are responsive and accessible.

------------------------------------------------------------------------

## 11. Phase 7 --- Frontend: general and beach-specific wind direction UI

**Goal:** Make direction preferences easy to understand and optional.

### 11.1 General direction UI

Add a "Wind direction" section to Weather Advisor preferences.

For each of the eight directions, provide a selector with exactly: -
Neutral - Bad - Very bad

Initial value: Neutral.

Suggested compact layout:

  Direction   Preference
  ----------- ------------
  N           Neutral
  NE          Neutral
  E           Neutral
  SE          Neutral
  S           Neutral
  SW          Neutral
  W           Neutral
  NW          Neutral

The interface may use a compass-style arrangement, but every direction
must also have a visible text label and accessible form control.

### 11.2 Beach-specific UI

Provide a "Customize for a beach" action:

1.  User searches/selects an existing BeachVolleyballHub Location.
2.  UI loads any saved overrides.
3.  Display all eight directions.
4.  Show whether each direction is inherited or customized.
5.  Allow Neutral, Bad, or Very bad.
6.  Allow clearing an override to inherit the general setting.
7.  Save changes.

Suggested labels:

-   `Inherited: Bad`
-   `Custom: Very bad`
-   `Custom: Neutral`

A custom Neutral must be visibly different from an unset/inherited
direction.

### 11.3 Effective preference preview

For a selected beach, show the effective result after inheritance.
Example:

  Direction   General   Beach override   Effective
  ----------- --------- ---------------- -----------
  E           Bad       Not set          Bad
  SE          Bad       Very bad         Very bad
  W           Neutral   Neutral          Neutral

This preview helps users understand why a beach behaves differently.

### 11.4 UI behavior

-   Do not require beach overrides.
-   Do not require the user to enter compass degrees.
-   Do not ask for court position/orientation.
-   Do not describe any direction as Good or Very good.
-   Clearly explain that directions only add a penalty or leave the wind
    score unchanged.

**Acceptance criteria**

-   General preferences can be edited independently.
-   A beach can override selected directions only.
-   Clearing an override restores inheritance.
-   Explicit Neutral is saved and overrides general Bad/Very bad.
-   UI does not introduce court-orientation setup.

------------------------------------------------------------------------

## 12. Phase 8 --- Integrate preferences into weather forecast and advisor responses

**Goal:** Ensure the actual forecast uses the correct user and beach
settings.

### Implementation tasks

1.  Identify where the forecast request is associated with a user and
    Location.
2.  Load the user's normalized weights and conditions.
3.  Resolve general and beach-specific direction preferences for that
    location.
4.  Pass normalized preferences into the advisor.
5.  Ensure public/anonymous forecasts use the current default behavior
    if that is how the existing app works.
6.  Ensure a user without saved preferences receives the
    legacy-equivalent defaults.
7.  Avoid N+1 queries when calculating multiple locations.
8.  Cache only where safe: cache keys must account for the preference
    values or a preference version, and must not leak personalized
    scores between users.
9.  Keep raw weather-provider data separate from personalized score
    output.
10. Return enough score breakdown information for the UI to explain the
    recommendation.

### Response/score breakdown

Where the existing API supports it, expose: - Base wind score. - Wind
direction bucket detected from the forecast. - Effective direction
preference. - Applied direction penalty. - Adjusted wind score.

Do not expose another user's preference data. For public forecasts, do
not claim a personalized direction adjustment was applied when no user
preferences were used.

**Acceptance criteria**

-   Forecast for the same beach can differ between users with different
    preferences.
-   Same user can receive different wind-direction adjustments at
    different beaches.
-   Weather provider data remains unchanged.
-   Caching does not mix personalized scores.

------------------------------------------------------------------------

## 13. Phase 9 --- Automated test plan

Use the existing RSpec, request-spec, and frontend test conventions in
the repository.

### 13.1 Advisor unit tests

**Default behavior** - No saved conditions uses legacy-equivalent
thresholds. - No direction preferences applies zero direction penalty. -
Existing weight calculation remains unchanged.

**Condition thresholds** - Test each parameter at boundary and
intermediate values. - Test custom thresholds change only the intended
parameter score. - Test invalid or partial preferences. - Test missing
provider values.

**Direction conversion** - 0° maps to N. - 22.5° boundary follows the
documented boundary rule. - 45° maps to NE. - 90° maps to E. - 135° maps
to SE. - 180° maps to S. - 225° maps to SW. - 270° maps to W. - 315°
maps to NW. - Values near 360° map correctly to N. - Nil, invalid, and
missing directions do not cause penalties.

Use tests immediately below, exactly at, and immediately above sector
boundaries to avoid ambiguous behavior.

**Penalty application** - Neutral = 0. - Bad = -10. - Very bad = -20. -
Wind subscore is clamped at its minimum and maximum. - Direction penalty
is applied to wind only. - Existing wind weight is applied after wind
score adjustment. - No positive direction modifier is possible.

### 13.2 Preference resolution tests

-   No beach override uses general preference.
-   Beach Bad overrides general Neutral.
-   Beach Very bad overrides general Bad.
-   Beach explicit Neutral overrides general Very bad.
-   Missing general preference resolves to Neutral.
-   Missing direction key inherits.
-   Removing an override restores inheritance.

### 13.3 Model/persistence tests

-   Valid values save.
-   Invalid directions reject.
-   Invalid enum values reject.
-   Partial updates preserve other keys.
-   User/account ownership is enforced.
-   Beach override references a valid existing Location.
-   One user cannot access another user's private preferences.

### 13.4 API request tests

-   Read current settings.
-   Update weights only.
-   Update conditions only.
-   Update general directions.
-   Create/update beach overrides.
-   Clear beach overrides.
-   Unauthenticated requests are rejected where required.
-   Unauthorized location/user access is rejected.
-   Invalid payloads return the standard validation response.

### 13.5 Frontend tests

-   Existing weights still render and save.
-   Condition controls load defaults and saved values.
-   Unit labels are correct.
-   Direction selectors show only Neutral, Bad, Very bad.
-   General settings save.
-   Beach settings show inherited and custom values.
-   Clearing a beach override restores the general value.
-   Explicit Neutral remains a custom override.
-   Loading, error, and success states work.
-   Mobile layout remains usable.

### 13.6 Regression tests

Run the complete relevant backend and frontend suites. Compare
representative forecast scores before and after the change using default
settings.

Any score difference under default settings must be explained and
explicitly approved.

------------------------------------------------------------------------

## 14. Phase 10 --- Documentation, rollout, and deployment

### Documentation

Update project documentation with:

-   Preference fields and defaults.
-   Units and threshold semantics.
-   Wind direction provider semantics (wind coming FROM).
-   Eight compass-sector boundaries.
-   Direction penalty values.
-   General-to-beach override precedence.
-   Missing-direction behavior.
-   API payload examples.
-   How to reset preferences.
-   How to add or remove beach overrides.

### Rollout

1.  Deploy database changes, if any.
2.  Deploy backend code with backward-compatible defaults.
3.  Verify existing users and anonymous forecast behavior.
4.  Deploy frontend.
5.  Test one user with default settings.
6.  Test one user with customized thresholds.
7.  Test one user with general wind-direction preferences.
8.  Test a beach-specific override, including explicit Neutral.
9.  Verify no personalized cache leakage.
10. Monitor errors and score distributions.

If a feature flag pattern already exists, consider using it for the
beach-specific wind-direction UI. Do not introduce a feature-flag system
solely for this change.

### Rollback

-   Keep migrations additive where possible.
-   Ensure older preference records remain readable.
-   If the frontend must be rolled back, backend defaults should
    continue working.
-   If directional scoring must be disabled, it should be possible to
    ignore direction preferences without losing saved settings.
-   Do not delete user preferences as part of a rollback.

------------------------------------------------------------------------

## 15. Suggested implementation order and deliverables

  Phase   Deliverable
  ------- --------------------------------------------------------
  0       Existing implementation audit and baseline tests
  1       Agreed preference contract and scoring specification
  2       Persistence and validation for condition thresholds
  3       Condition-aware `Weather::VolleyballAdvisor`
  4       Wind-direction mapping, penalties, and beach overrides
  5       API endpoints, authorization, and serializers
  6       Frontend condition settings
  7       Frontend general and beach direction settings
  8       Forecast integration and score breakdown
  9       Complete automated test coverage
  10      Documentation, rollout, and deployment

Phases may be combined where the repository architecture makes that
sensible, but keep the scoring logic and preference-resolution tests
independent.

------------------------------------------------------------------------

## 16. AI coding prompts for each phase

Use these prompts with Codex or another coding agent from the repository
root. Each prompt instructs the agent to inspect the real project before
editing and to avoid assuming paths or schema.

### Prompt --- Phase 0: Audit

> Inspect the BeachVolleyballHub Rails API and React/Vite frontend. Find
> `Weather::VolleyballAdvisor` (`advisor.rb`), the existing weather
> weight configuration, persistence, API endpoints, weather provider
> mapping, Location model, and frontend Weather Advisor settings UI. Do
> not modify code yet. Document the current score calculation, every
> existing threshold, score ranges, recommendation bands, missing-data
> behavior, preference ownership, and relevant tests. Identify the
> smallest compatible implementation path for configurable condition
> thresholds and optional general/beach-specific wind-direction
> preferences. Preserve existing behavior by default. Report exact file
> paths and risks.

### Prompt --- Phase 1: Preference contract

> Based on the actual repository audit, propose the final preference
> contract for Weather Advisor. Keep existing weights separate from new
> condition thresholds. Include only parameters already scored by the
> advisor. Define units, defaults copied from existing behavior,
> validation, partial-update behavior, and missing-value behavior.
> Define eight wind directions (N, NE, E, SE, S, SW, W, NW) with only
> Neutral, Bad, and Very bad. Direction penalties are 0, -10, and -20
> applied to the wind subscore only, then clamped before existing
> weighted aggregation. Define precedence: beach override, general user
> preference, Neutral. Explicit beach Neutral must override general
> Bad/Very bad; missing beach key means inherit. Do not add court
> orientation or court records. Present the contract and proposed file
> changes before implementation.

### Prompt --- Phase 2: Persistence and validation

> Implement persistence for configurable Weather Advisor condition
> thresholds and wind-direction preferences using the existing
> preference ownership and storage conventions. Preserve current weight
> settings and legacy-equivalent defaults. Add beach-specific direction
> overrides associated with the existing Location model and the correct
> user/account owner. Support partial updates. Validate all keys, units,
> ranges, direction names, and enum values. Distinguish an absent beach
> override from an explicit Neutral override. Add model/service tests
> and migrations only where needed. Do not modify scoring or frontend
> yet. Run relevant tests and summarize changes.

### Prompt --- Phase 3: Condition-aware advisor

> Refactor `Weather::VolleyballAdvisor` to accept normalized user
> preferences and use configurable thresholds for every weather
> parameter that is already scored. Extract existing thresholds as
> defaults so users without custom settings retain current behavior.
> Preserve existing scoring curves, weights, score normalization, and
> recommendation bands. Keep parsing, persistence, and scoring
> responsibilities separate. Handle missing provider values consistently
> with existing behavior. Add thorough unit tests for boundaries,
> intermediate values, partial preferences, defaults, and two users
> receiving different scores for the same forecast. Do not implement
> wind direction in this phase. Run tests and report default-score
> comparisons.

### Prompt --- Phase 4: Wind direction scoring

> Implement optional wind-direction scoring in
> `Weather::VolleyballAdvisor` and supporting services. Verify the
> weather provider reports meteorological wind direction (the direction
> wind comes FROM). Map degrees to the nearest of eight compass
> directions using documented 45-degree sectors and correct wraparound
> at North. Resolve preferences using beach override, then general user
> preference, then Neutral. An explicit beach Neutral must override a
> general penalty; an absent beach key must inherit. Map Neutral to 0,
> Bad to -10, Very bad to -20. Apply the penalty only to the base wind
> subscore and clamp to its valid range before existing weighted
> aggregation. If direction is missing or invalid, apply no directional
> penalty. Do not add a direction weight, positive bonus, court bearing,
> or trigonometric calculation. Add boundary, precedence, missing-data,
> and score-clamping tests.

### Prompt --- Phase 5: API

> Extend the existing Weather Advisor preference and forecast APIs to
> read and update weights, condition thresholds, general wind-direction
> preferences, and beach-specific direction overrides. Follow current
> routes, serializers, authentication, and authorization conventions.
> Support partial updates without resetting unrelated values. Validate
> allowed fields server-side. Ensure users can only read and change
> their own preferences and authorized Location overrides. Return
> effective settings and enough metadata for the frontend to distinguish
> inherited values from explicit overrides. Add request specs for
> success, validation errors, authentication, authorization, and partial
> updates. Do not create duplicate endpoints if existing endpoints can
> be extended cleanly.

### Prompt --- Phase 6: Condition settings UI

> Extend the existing Weather Advisor settings UI. Keep all existing
> weight sliders and behavior. Add a Weather conditions section with
> editable thresholds for the parameters actually scored by the backend.
> Use clear labels, units, sensible numeric inputs/sliders, validation,
> loading/saving states, and reset-to-defaults behavior. Fetch and
> persist values through the existing API client patterns. Do not
> hardcode threshold defaults independently in the frontend; use
> backend-provided defaults. Ensure partial saves do not overwrite
> weights or wind-direction preferences. Add frontend tests and verify
> mobile responsiveness.

### Prompt --- Phase 7: Wind direction UI

> Add general and beach-specific wind-direction preference controls to
> the existing Weather Advisor settings experience. Use exactly eight
> directions: N, NE, E, SE, S, SW, W, NW. Each selector must offer only
> Neutral, Bad, Very bad. General settings default to Neutral. Add an
> optional beach selector/search using existing Locations. For a
> selected beach, show inherited versus custom preferences. Allow the
> user to set an explicit Neutral override and to clear an override to
> inherit the general preference. Explain that wind direction can only
> penalize the wind score, never improve it. Do not ask for court
> orientation or compass degrees. Add frontend tests for inheritance,
> explicit Neutral, saving, and clearing overrides.

### Prompt --- Phase 8: Forecast integration

> Integrate normalized user weights, condition thresholds, and resolved
> wind-direction preferences into the existing weather forecast/advisor
> flow. Ensure the correct Location is used for beach overrides and the
> correct user/account owns the preferences. Keep raw provider weather
> data separate from personalized scoring. Expose a score breakdown
> consistent with existing API conventions, including base wind score,
> detected direction, effective preference, applied penalty, and
> adjusted wind score where appropriate. Review caching carefully so
> personalized scores cannot be shared across users. Preserve
> anonymous/default behavior and avoid N+1 queries. Add integration
> tests.

### Prompt --- Phase 9: Full test and regression pass

> Run the relevant Rails and frontend test suites for the Weather
> Advisor changes. Add missing tests for all condition thresholds,
> direction-sector boundaries, preference inheritance, explicit Neutral
> overrides, missing/invalid wind direction, score clamping, weight
> application, authorization, and frontend behavior. Compare
> representative forecast scores using default preferences against the
> pre-change baseline. Fix regressions without changing agreed product
> behavior. Report test commands, results, default-score differences,
> and any remaining risks.

### Prompt --- Phase 10: Documentation and release readiness

> Update BeachVolleyballHub documentation for the Weather Advisor
> personalization feature. Explain weights versus condition thresholds,
> units/defaults, wind direction as wind coming FROM, eight direction
> sectors, Neutral/Bad/Very bad penalties, beach-over-general
> precedence, explicit Neutral overrides, missing direction behavior,
> API usage, and rollout/rollback. Review migrations and deployment
> order. Provide a production smoke-test checklist and confirm older
> users retain legacy-equivalent behavior. Do not claim deployment has
> happened; report only verified repository changes and test results.

------------------------------------------------------------------------

## 17. Definition of done

The implementation is complete when all of the following are true:

-   [ ] Existing weight configuration still works and is not replaced.
-   [ ] Users can configure thresholds/tolerances for the existing
    scored weather parameters.
-   [ ] Defaults reproduce current Weather Advisor behavior as closely
    as possible.
-   [ ] Same weather can produce different scores for users with
    different conditions.
-   [ ] General wind-direction preferences support exactly eight compass
    directions.
-   [ ] Wind-direction values are only Neutral, Bad, and Very bad.
-   [ ] Direction penalties are 0, -10, and -20 respectively.
-   [ ] No positive wind-direction modifier exists.
-   [ ] Direction penalty modifies only the wind subscore.
-   [ ] Missing/invalid forecast direction causes no directional
    penalty.
-   [ ] General preferences apply across beaches.
-   [ ] Beach-specific overrides take precedence over general
    preferences.
-   [ ] Explicit beach Neutral overrides a general penalty.
-   [ ] Unset beach directions inherit general preferences.
-   [ ] Users cannot access or modify another user's private
    preferences.
-   [ ] No court orientation, court GPS, or geometry feature was
    introduced.
-   [ ] Backend and frontend tests pass.
-   [ ] Default-score regression checks are reviewed.
-   [ ] Documentation and rollout instructions are updated.

## 18. Final implementation guidance

Keep this feature deliberately practical.

The Weather Advisor should have three independent inputs:

1.  **Weights:** how important each weather factor is to the user.
2.  **Conditions:** what values the user considers comfortable or
    unacceptable.
3.  **Wind direction preferences:** which compass directions make
    conditions worse, generally or at a particular beach.

The scoring engine combines those inputs while preserving the existing
overall scoring model.

Do not turn this into a court-mapping project. Users should be able to
personalize the advisor with a few simple settings, and users who do
nothing should continue to receive the existing default experience.
