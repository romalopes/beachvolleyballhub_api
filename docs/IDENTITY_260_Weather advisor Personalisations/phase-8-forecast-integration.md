# Phase 8 — Forecast Integration and Score Breakdown

**Status:** Completed
**Date:** 2026-11-19
**Scope:** Personalized assessments across current + hourly forecast

---

## 1. Backend Integration

`Api::V1::WeatherController#show` now assesses **both** the current block
and every hourly entry with the signed-in account's full preference set
(weights + effective conditions + general wind directions):

- `personalized_assessment(forecast)` — current conditions
- `hourly_with_assessments(forecast)` — each 3-hourly forecast entry

Guests and accounts without a saved preference fall through to advisor
defaults — behavior identical to the pre-personalization baseline
(verified by `weather_controller_test.rb` guest/weights tests).

## 2. Cache Isolation

The shared provider cache key (`weather/v4/<lat>,<lon>/days-3`) stores only
provider-normalized data with the **default** assessment. The controller
`deep_dup`s the payload before overwriting `volleyball` and `hourly` blocks
with personalized results, so:

- No user-specific scores are ever written to the shared cache
- Two accounts with different preferences hitting the same coordinates
  get different scores from the same cached provider payload
- Provider quota is protected (one upstream call per coordinate window)

## 3. Frontend Integration

- `WeatherWidget` / forecast modal consume `volleyball` blocks as before —
  the personalized score appears without frontend changes to display logic
- `WeatherAdvisorPreferences` broadcast `WEATHER_PREFERENCE_CHANGED_EVENT`
  after save/reset; the widget refreshes its weather query so the new
  scores appear immediately
- Deep link `/account#weather-advisor-preferences` scrolls and focuses the
  section after the async load (existing behavior, retested)

## 4. Score Breakdown Transparency

The `/account` panel documents factor scoring and label bands
(Excellent 85+, Good 70+, Fair 50+, Poor 30+, Unsuitable <30), the
missing-data renormalization rule, and the independent-safety-warnings
guarantee. Direction penalty semantics (0/-10/-20, reduce-only) are stated
in the direction section.

## 5. Tests

- `weather_controller_test.rb`: 10 tests — normalized contract, per-hour
  assessments, account weights on hourly + current, guest defaults,
  coordinate validation, provider errors
- `WeatherWidget.test.tsx`: 15 tests pass with the extended pipeline
- Component refresh-event test verifies save triggers a refetch