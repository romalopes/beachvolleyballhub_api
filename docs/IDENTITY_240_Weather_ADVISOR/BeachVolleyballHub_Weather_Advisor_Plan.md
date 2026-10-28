# BeachVolleyballHub — Weather Advisor Implementation Plan

**Prepared:** 27 October 2026
**Target:** React/TypeScript frontend (`beachvolleyballhub_frontend`) + Rails API (`beachvolleyballhub_api`)
**Primary entry point:** `Home.tsx`, directly below the location/map section
**Budget constraint:** **AUD $0 recurring weather-provider fees**. Do not introduce a paid service, trial that auto-converts to paid, or credit-card requirement.

> **Important:** This is an implementation blueprint, not a verified audit of the latest repository HEAD. The coding assistant must inspect actual current files, routes, conventions and tests before modifying anything. Existing location handling was described in the preceding review; do not assume line numbers or component props remain unchanged.

## 1. Decision: free commercial-use weather provider

**Recommended: WeatherAPI.com Free**, because it explicitly permits commercial use on the free plan. Its forecast is **3 days**, not 7. Do **not** falsely display a 7-day forecast using the free tier. For a $0 budget, ship a 3-day forecast and design the UI/API to support seven days later if a suitable legally permitted free source becomes available.

| Provider                     |               Free price | Free forecast         | Commercial use                                                   | API key              | Decision                                                                  |
| ---------------------------- | -----------------------: | --------------------- | ---------------------------------------------------------------- | -------------------- | ------------------------------------------------------------------------- |
| **WeatherAPI.com Free**      |                   **$0** | **3 days**            | **Yes**                                                          | **Yes; free signup** | **Use for production MVP**                                                |
| Open-Meteo hosted Free API   |                       $0 | Typically 7–16 days   | **No**, unless use qualifies as non-commercial                   | No                   | Use only for clearly non-commercial prototypes, not commercial production |
| Open-Meteo self-hosted       | No provider subscription | Depends on deployment | Requires review of AGPLv3, data attribution and operational cost | No provider key      | Not recommended for $0 managed hosting budget                             |
| BOM public forecast/warnings |           Public website | Varies                | Licensing, API availability and permitted reuse must be checked  | Depends on interface | Link to official warnings; do not scrape or claim an unrestricted API     |

WeatherAPI.com advertises **100,000 free calls/month**, commercial use and 3-day forecasts. **Free-tier attribution is required**. Its terms also say a key/subscription is for one application; verify whether the frontend/backend together constitute one application and whether additional deployments or future products need separate keys. See official sources at end.

### What you must register / configure

1. Create a free account at https://www.weatherapi.com/ (no credit card advertised).
2. Copy the issued API key from the WeatherAPI dashboard.
3. In **Render** for the Rails API, set secret environment variable `WEATHERAPI_API_KEY=<your key>`.
4. Locally, use Rails credentials or a gitignored `.env` file as your existing project conventions allow. **Never commit the key.**
5. No new frontend `VITE_*` key is required: browser requests go to your Rails API.
6. No Google Maps API key, Geoapify key, IP lookup key, Open-Meteo key, database migration or paid account is needed **for the weather MVP**. Existing map/location services may have their own separate credentials.
7. Add visible **“Weather data: WeatherAPI.com”** attribution linking to the provider, as required by its free terms.

**Key checklist:** `WEATHERAPI_API_KEY` is **required and free**; `WEATHER_PROVIDER=weatherapi` is optional; `WEATHER_CACHE_TTL_SECONDS=1800` is optional; `WEATHER_FORECAST_DAYS=3` is optional. Keep credentials server-side. Do not expose the key through React, browser network responses, frontend build variables, Rails logs or Sentry.

## 2. Product scope and acceptance criteria

### MVP (free)

- Place reusable `<WeatherWidget />` **under the existing location/map** in `Home.tsx`.
- Reuse selected or detected coordinates; preserve the current browser geolocation → IP fallback → Coogee fallback behavior _if that is what the latest code actually does_.
- Show selected location name, data freshness, current temperature, feels-like, wind speed/direction/gusts, humidity, UV, precipitation and condition icon/description.
- Show **today plus next 2 days** (3-day forecast), with daily min/max, rain chance, max wind/gust and condition.
- Show a **Beach Volleyball Suitability** rating and actionable coaching advice; provide a simple beginner/intermediate/advanced preference, if easy to implement.
- Show a prominent **safety advisory** for dangerous conditions; avoid asserting safety based on a score.
- Display provider attribution and a link to official local warnings (Australia: https://www.bom.gov.au/).
- Handle missing location, invalid coordinates, provider failure, quota exhaustion and stale cache gracefully. Home page must still render.
- No paid services, no new database tables and no background scheduler for MVP.

### Future (not in MVP)

- 7-day forecast **only if a compliant $0 commercial source is verified** or budget policy changes.
- Hourly forecast aligned with training/tournament start/end times.
- Saved beach location preference, wind relative to court orientation, best time to play, event-specific notifications, official severe-weather alert ingestion.
- Do not promise real-time lightning detection or authoritative safety clearance from a general forecast feed.

## 3. Repository discovery (mandatory first step)

Frontend: https://github.com/romalopes/beachvolleyballhub_frontend
Backend: https://github.com/romalopes/beachvolleyballhub_api

Inspect before editing:

- Actual location of `Home.tsx` (likely `src/pages/Home.tsx`), imports, state, location/map rendering and search behavior.
- `LocationMap` props and whether search text is geocoded to coordinates. Never show detected-location weather under a different searched location name.
- Existing API client/auth helpers, TypeScript models, styling conventions (Bootstrap/CSS), loading/error patterns, frontend tests.
- Rails API namespaces, routing, service objects, HTTP clients, CORS, rate limiting, caching configuration and request specs.
- Whether Cloudflare/Render forwarding and geolocation are already configured. Reuse rather than duplicate.

**Search commands (adapt paths):**

```bash
# Frontend
git status --short
find src -iname '*Home*' -o -iname '*Location*' -o -iname '*Weather*'
rg 'detectedLocation|LocationMap|geolocation|searchedLocation|apiClient' src
cat package.json

# Backend
rg 'namespace :api|Rails.cache|Faraday|Net::HTTP|rack-attack|weather' app config spec test Gemfile
cat config/routes.rb
```

If a command shows a different architecture, follow actual code, not this proposed file tree.

## 4. Architecture

```text
Home.tsx
  ├─ existing location selection / detection
  ├─ existing map
  └─ WeatherWidget(lat, lon, locationName)
       └─ useWeather(lat, lon)
            └─ frontend API client
                 └─ GET /api/v1/weather?latitude=...&longitude=...
                      └─ Rails Weather::ForecastService
                           ├─ validate lat/lon
                           ├─ Rails.cache (coordinate-rounded key, TTL)
                           ├─ Weather::WeatherApiClient
                           ├─ normalize data
                           └─ Weather::VolleyballAdvisor
```

Keep provider response parsing and scoring **in Rails**, with a stable frontend contract. Frontend should never call the third-party provider directly. For requests with searched text but no coordinates, prompt user to select a resolved location or hide the widget.

### Suggested backend files (adjust to existing conventions)

```text
app/controllers/api/v1/weather_controller.rb
app/services/weather/weather_api_client.rb
app/services/weather/forecast_service.rb
app/services/weather/volleyball_advisor.rb
spec/requests/api/v1/weather_spec.rb
spec/services/weather/*_spec.rb
```

### Suggested frontend files

```text
src/components/weather/WeatherWidget.tsx
src/components/weather/CurrentWeather.tsx
src/components/weather/WeatherForecast.tsx
src/components/weather/WeatherAdvice.tsx
src/hooks/useWeather.ts
src/services/weatherService.ts
src/types/weather.ts
```

Do not create extra components merely for architectural purity; start small.

## 5. API contract

**Endpoint:** `GET /api/v1/weather?latitude=-33.919655&longitude=151.258574`

Validate numeric coordinates in ranges latitude -90..90 and longitude -180..180; reject NaN/Infinity/malformed values with HTTP 422. Consider API rate limiting to prevent key quota abuse. Round cache coordinates to approximately 2–3 decimal places (decide based on beach precision and privacy). Include location timezone from provider.

**Example response (illustrative values only):**

```json
{
  "provider": "weatherapi",
  "attribution": "WeatherAPI.com",
  "location": {
    "latitude": -33.919655,
    "longitude": 151.258574,
    "timezone": "Australia/Sydney"
  },
  "updated_at": "2026-10-27T05:00:00Z",
  "stale": false,
  "current": {
    "temperature_c": 23.0,
    "feels_like_c": 24.0,
    "condition": "Partly cloudy",
    "condition_code": 1003,
    "wind_kph": 18.0,
    "wind_gust_kph": 27.0,
    "wind_degree": 45,
    "wind_direction": "NE",
    "humidity_percent": 64,
    "uv_index": 6.0,
    "precipitation_mm": 0.0
  },
  "daily": [
    {
      "date": "2026-10-27",
      "min_c": 18,
      "max_c": 25,
      "rain_chance_percent": 20,
      "max_wind_kph": 24,
      "condition": "Partly cloudy"
    }
  ],
  "volleyball": {
    "score": 78,
    "label": "Good",
    "advice": [
      "Moderate wind: practise controlled setting.",
      "UV is elevated: use sun protection."
    ],
    "warnings": [],
    "safety_override": false
  }
}
```

Use `null` for genuinely missing measurements; do not fabricate. Document which source field maps to each normalized field. If provider supplies only forecast gusts rather than current gusts, label them accurately. Never treat a forecast as an official lightning warning.

**Failure contract:** 422 invalid coordinates; 503 weather provider unavailable and no usable cache; 429 when your own throttling applies. Do not leak upstream API keys or full provider errors.

## 6. WeatherAPI integration

Provider endpoint: `https://api.weatherapi.com/v1/forecast.json`.

Server-side example (replace placeholder):

```bash
curl --get 'https://api.weatherapi.com/v1/forecast.json' \
  --data-urlencode 'key=YOUR_FREE_API_KEY' \
  --data-urlencode 'q=-33.919655,151.258574' \
  --data-urlencode 'days=3' \
  --data-urlencode 'aqi=no' \
  --data-urlencode 'alerts=no'
```

**Note:** Putting a key in a command line or URL can expose it in shell history/logs. For real use, load the key from a secret environment variable and avoid logging request URLs. Check provider docs for available parameters on the Free plan. `alerts=no` means official warning integration is out of scope.

Implementation rules:

- Timeout 3–5 seconds; small bounded retry only for transient errors, never indefinite retry.
- Cache successful normalized response 20–30 minutes per rounded coordinate; optionally stale-if-error for a bounded period with clear stale label.
- No weather fetch on every React render; request only when coordinates change, deduplicate concurrent requests and cancel obsolete requests.
- Avoid unnecessary location precision in analytics or logs.
- Record errors and quota events in existing Sentry integration without leaking key/precise location.
- Respect free plan's 100,000 calls/month and one-application restriction. If two independent apps eventually consume the provider, check key terms.

## 7. Beach-volleyball scoring and safety

Implement deterministic, unit-tested scoring with configurable thresholds. Initial **coaching suitability** (not a certified safety rating):

| Factor                   | Proposed weight | Notes                                    |
| ------------------------ | --------------: | ---------------------------------------- |
| Wind and gusts           |             40% | Gustiness may matter more than mean wind |
| Temperature / feels-like |             20% | Heat stress is multifactorial            |
| Rain                     |             25% | Heavy rain can affect play               |
| UV                       |              5% | Show strong sun protection advice        |
| Humidity / other         |             10% | Avoid overconfidence                     |

Rating: 85–100 Excellent, 70–84 Good, 50–69 Fair, 30–49 Poor, 0–29 Unsuitable. These are product heuristics, **not official safety standards**. For high UV, extreme heat, storms or dangerous gusts, show warning banners independently of the score. Without authoritative warnings, never claim “safe to play.” Do not use forecast-based scoring as the sole cancellation criterion.

Suggested initial wind coaching bands (configurable):

- 0–10 km/h: ideal for precision drills.
- 11–20 km/h: generally good, mild adjustments.
- 21–30 km/h: challenging; practise wind-adjusted skills.
- 31–40 km/h: difficult; coach assesses suitability and gusts.
- > 40 km/h: consider postponement; evaluate local hazards.

Do not hard-code these as official safety thresholds. Wind conditions at court level may differ from forecast grid cells.

## 8. Home.tsx integration details

- Keep existing location selector, map and hero intact.
- Render the widget directly below `LocationMap` inside the location section, subject to actual JSX structure.
- Pass **resolved** `latitude`, `longitude`, and display name.
- When a user searches for a place, use the existing geocoding result's coordinates if available; if only a text query exists, do **not** attach old-location weather to new-location label.
- If browser geolocation is declined, respect existing fallback and clearly label approximate/fallback location.
- Do not automatically request high-accuracy GPS solely for weather.
- On mobile: current summary first, forecast cards horizontally scrollable or stacked, advisory beneath; accessible labels for wind direction and icons.
- Loading skeleton, retry button, last-updated indicator, attribution link and graceful offline state.
- Preserve existing auth and navigation.

Suggested JSX (adapt variable names after inspecting source):

```tsx
{
  resolvedLocation?.latitude != null && resolvedLocation?.longitude != null && (
    <WeatherWidget
      latitude={resolvedLocation.latitude}
      longitude={resolvedLocation.longitude}
      locationName={resolvedLocation.name ?? "Selected location"}
    />
  );
}
```

## 9. Step-by-step implementation phases and AI prompts

### Phase 0 — Audit the real repositories

**Deliverable:** short report of exact files/routes to change, current location flow and reusable code; no code changes.

**AI prompt:**

> Inspect the current `beachvolleyballhub_frontend` and `beachvolleyballhub_api` repositories. Find the real `Home.tsx`, location detection, search/geocoding, map, API client, Rails routing, cache and test conventions. Produce an evidence-based implementation map with exact paths and potential pitfalls. Do not assume previous code snippets still match HEAD. Do not modify files yet. Keep the solution free of recurring provider charges and commercially permitted.

### Phase 1 — Set up the free API key

**Manual actions:** Register a **free** WeatherAPI.com account, obtain a key, set `WEATHERAPI_API_KEY` in Render and local gitignored secrets. Do not share the key in AI chat or commit it.

**AI prompt:**

> Add documented `WEATHERAPI_API_KEY` configuration to the Rails project following its existing environment/credentials conventions. Validate key presence in the weather service without breaking boot when the feature is disabled. Add a redacted example to `.env.example` if appropriate, and deployment notes for Render. Never expose or log the key. No paid tools.

### Phase 2 — Rails weather endpoint and caching

**Deliverable:** `GET /api/v1/weather`, validation, WeatherAPI client, normalized JSON, caching and error handling.

**AI prompt:**

> Implement a production-quality weather API endpoint in the current Rails codebase using **WeatherAPI.com Free** (`forecast.json`, `days=3`). Use server-side `WEATHERAPI_API_KEY`, coordinate validation, a 30-minute cache, provider timeouts, error mapping and request specs with stubbed external HTTP. Normalize current and daily forecasts for React. Do not introduce new database tables, background jobs, paid APIs or a 7-day claim. Follow the repository's existing controller/service patterns and API conventions. Include attribution in response and avoid logging credentials.

### Phase 3 — Volleyball advisor service

**Deliverable:** deterministic score, explanatory advice, safety override flags and tests.

**AI prompt:**

> Implement `Weather::VolleyballAdvisor` in Rails. Return a 0–100 **playing-suitability heuristic**, rating, wind-specific coaching tips, UV/heat/rain advice and separately displayed safety warnings. Use configurable thresholds and nil-safe calculations; never label conditions definitively safe or use unsupported lightning detection. Add unit tests for calm, windy, hot, rainy, high-UV and missing-data cases. Avoid paid services.

### Phase 4 — React WeatherWidget in Home.tsx

**Deliverable:** responsive component under the map, 3-day forecast and tests.

**AI prompt:**

> In the latest `beachvolleyballhub_frontend`, create a reusable TypeScript `WeatherWidget` with current conditions, wind/gusts/direction, UV, 3-day forecast, suitability score, recommendations, safety warnings, freshness and WeatherAPI.com attribution. Integrate it directly under the existing map in `Home.tsx`. Reuse existing resolved location coordinates and API client; do not duplicate geolocation logic or show incorrect weather for unresolved search text. Match current UI styling, support mobile/accessibility, and add component/hook tests with mocked API responses. No frontend weather API key.

### Phase 5 — Quality, security and deployment

**Deliverable:** green tests, deployment, monitoring and documented limitations.

**AI prompt:**

> Review the weather feature end-to-end for key leakage, abuse/rate limiting, cache efficiency, error handling, quota exhaustion, accessibility, location privacy, timezone correctness and attribution. Run existing frontend and backend lint/typecheck/tests. Add a small manual test checklist for Coogee, browser permission denied, searched location, invalid coordinates, upstream timeout and mobile display. Document free-tier limits and why forecast is 3 days. Do not purchase or enable any paid product.

### Phase 6 — Optional future integration (no implementation now)

**AI prompt:**

> Propose, but do not implement, a later extension of the weather advisor to Location, Training Session and Tournament pages using the same normalized Rails endpoint. Describe event-time hourly forecasts, forecast horizon limitations, caching and a best-time-to-play feature. Preserve the $0 provider constraint and explicitly identify anything that would require a paid tier or a newly verified free commercial-use data source.

## 10. Optional free Weather Map feature (new)

**Goal:** Add an interactive, optional **View Weather Map** panel below the existing Home location map / WeatherWidget, with selectable **precipitation, wind, temperature and pressure** tile overlays, forecast-hour selection, legend and opacity control. Do not replace the existing Google Maps location component in the MVP.

### Free-first architecture and prerequisites

- **Preferred:** React + **Leaflet** (open-source, no Leaflet API key) and a permitted base-map tile service, with WeatherAPI weather-map raster tiles overlaid on top. Confirm the chosen base tile provider's **commercial-use terms, attribution and request limits**; Leaflet being free does _not_ make every tile provider free.
- **Alternative:** Google Maps JavaScript API `ImageMapType` overlays. This **requires a Google Maps JavaScript API key, enabled API and billing configuration**, and may incur charges. **Do not enable this alternative** under the strict $0 requirement. The existing Google Maps Embed iframe cannot accept custom overlay tiles.
- **Weather map tiles:** WeatherAPI documentation describes public weather-map tile URLs (e.g. `https://weathermaps.weatherapi.com/wind/tiles/{yyyyMMddHH}/{z}/{x}/{y}.png`). **Verify current official docs, supported layers, forecast timestamps, attribution, usage limits, commercial rights and whether a map-specific key is required before implementation.** Do not assume the tile service has unlimited free commercial use simply because its URLs are public. If rights/limits cannot be confirmed, disable the map feature and ship the free WeatherWidget alone.
- **WeatherAPI forecast JSON:** continues to require the existing free `WEATHERAPI_API_KEY` on Rails. Map tiles and forecast JSON are separate services.
- **Browser credentials:** no new frontend weather key _if_ public tiles remain authorized without one; never embed `WEATHERAPI_API_KEY` in tile URLs or `VITE_*` variables.
- **Base map:** choose a tile service with documented permission for this traffic level. Respect attribution and caching rules. Do not use public OpenStreetMap Foundation tile servers as an assumed unlimited production CDN.

### Suggested components

```text
src/components/weather/
  WeatherWidget.tsx            # existing planned forecast panel
  WeatherMap.tsx               # optional, lazy-loaded Leaflet map
  WeatherMapControls.tsx       # layer / forecast-hour / opacity
  WeatherMapLegend.tsx         # layer-specific units and colours
src/services/
  weatherMapTiles.ts           # URL generation and valid times
```

**UI:** `Home.tsx` → existing `LocationMap` → `WeatherWidget` → **View Weather Map** (collapsed by default). On expansion, centre Leaflet on the _same resolved coordinates_ used by the widget; if a text search has not been geocoded, don't label the map as showing that searched place. Keep the current map unchanged.

**Layer controls:** None / Rain / Wind / Temperature / Pressure. Display a single overlay at a time. Add a forecast-hour selector constrained to the provider's actually available timestamps (UTC); do not assume every hour is published. Add a legend and attribution for the weather tiles **and** base tiles. If tiles fail or the selected time is unavailable, show a friendly message and preserve the rest of Home.

**Performance and accessibility:** lazy-load Leaflet only when expanded, avoid unnecessary tile refreshes, clean up overlay layers on unmount, support keyboard-accessible controls, and provide a text summary for users who cannot interpret coloured maps. Wind raster maps show spatial intensity; they do **not** necessarily show wind direction at the court, so retain numeric wind direction in WeatherWidget.

### Weather map implementation phases and AI prompts

**Phase M0 — Verify licensing and actual map code (mandatory gate).**

> Inspect the current frontend `LocationMap` and `Home.tsx`. Determine whether the map is a Google Maps Embed iframe or JavaScript API. Check WeatherAPI's current official Weather Maps documentation and terms for public tile endpoints, layers, UTC timestamp format, forecast range, attribution, quotas and commercial reuse; check the proposed base-map provider's production/commercial tile terms. Produce a short evidence-based decision table: allowed free, key required, paid/billing required, or unclear. **Do not implement** if any essential map-tile licensing or zero-cost requirement is unresolved. Do not add Google Maps JavaScript billing.

**Phase M1 — Build reusable Leaflet map (only after M0 passes).**

> Add a lazy-loaded `WeatherMap` React/TypeScript component using Leaflet, with a licensed $0 base-map tile provider and correct visible attribution. Accept `latitude`, `longitude`, `locationName` and optional forecast time. Render only after user expands View Weather Map. Preserve the existing Google map. Follow current project component styling, build tooling and test conventions; do not introduce a paid API or key.

**Phase M2 — Weather overlay and controls.**

> Implement WeatherAPI tile overlay URL generation from officially documented tile templates and valid UTC timestamps. Provide None/Rain/Wind/Temperature/Pressure selection, forecast-hour control, layer-specific legend and opacity slider. Correctly remove old tile layers, constrain time choices to provider availability, and handle missing tiles and network errors. Keep the normal WeatherWidget visible even when weather tiles fail. Do not expose the forecast JSON API key in frontend requests.

**Phase M3 — Integrate with Home and test.**

> Integrate a collapsible View Weather Map below the WeatherWidget in `Home.tsx`, sharing the same resolved location coordinates and avoiding mismatched search labels. Add tests for layer selection, UTC formatting, invalid times, overlay cleanup, missing tiles, attribution, lazy loading, mobile layout and accessibility. Run frontend lint/typecheck/tests and document any tile-provider usage limits. Verify no paid resources or billing-enabled APIs were introduced.

**Optional future:** Add a weather map to Location and event detail pages, reusing the component. Keep it separate from official warnings and the safety scoring logic.

---

## 11. Testing checklist

- [ ] Existing Home page works with weather API unavailable.
- [ ] Correct coordinates for detected, fallback and searched locations.
- [ ] Search text without coordinates does not produce misleading forecast.
- [ ] Current weather and **exactly up to 3 days** displayed.
- [ ] Provider attribution visible.
- [ ] API key never present in browser assets, response or logs.
- [ ] 422 for invalid coordinates; 503 or stale fallback for provider failures.
- [ ] Cache hits avoid duplicate external calls; cache keys don't include secrets.
- [ ] Score unit tests cover edge cases and warnings.
- [ ] Local dates use location timezone, not browser timezone.
- [ ] Responsive and keyboard/screen-reader accessible.
- [ ] Free monthly quota monitored; provider commercial terms followed.
- [ ] No credit-card or paid dependencies introduced.
- [ ] Weather map optional, lazy-loaded and uses the same resolved coordinates as the forecast.
- [ ] Weather and base-map tile licensing, attribution and quotas verified before deployment.
- [ ] Weather map layer controls, forecast UTC time and overlay cleanup tested.

## 12. Estimated cost and constraints

| Item                                       |                                          Expected new recurring cost | Key required?                   |
| ------------------------------------------ | -------------------------------------------------------------------: | ------------------------------- |
| WeatherAPI.com Free                        |                                                               **$0** | **Yes, free**                   |
| Rails service code                         |                                                  $0 software licence | No                              |
| React widget                               |                                                  $0 software licence | No                              |
| Existing Rails cache                       |                       $0 incremental if existing capacity sufficient | No                              |
| Existing Render/Cloudflare hosting         | No **new** subscription assumed; existing hosting limits still apply | Existing deployment credentials |
| BOM warnings website link                  |                                                                   $0 | No                              |
| Leaflet library                            |                                                                   $0 | No                              |
| WeatherAPI weather map tiles               |                       $0 **only if free commercial use is verified** | Verify current docs             |
| Base-map tile service                      |                       $0 **only if licensed free tier fits traffic** | Provider-dependent              |
| Google Maps JavaScript overlay alternative |                                      **Not guaranteed $0; excluded** | Yes + billing                   |
| Seven-day forecast on WeatherAPI.com       |                          **Not free** (Starter currently US$7/month) | Paid plan key                   |

**Recommendation:** ship a reliable, legally permitted **3-day free weather widget** rather than using a 7-day provider's non-commercial tier in a potentially commercial app. Revisit seven-day support only after verifying a compliant $0 provider or changing the budget.

## 14. Phase Documentation

The following phase documentation files have been created to track the implementation:

- `Phase-1-Weather-Service.md` - Backend WeatherAPI.com service implementation, including the `fetch_forecast` service method, controller, routes, and environment configuration.
- `Phase-2-Frontend-Integration.md` - React/TypeScript frontend integration in `Home.tsx`, including state management, weather fetch effect, 3-day forecast card grid UI, and API service method `api.weather(lat, lon)`.
- `Phase-3-Testing-And-Validation.md` - Testing and validation checklist covering unit tests, integration tests, manual testing, constraints verification, accessibility, and regression testing.

These phase files complement the original implementation plan and provide detailed guidance for each development stage.

### Implementation update — 28 October 2026

- The Home location area now uses a responsive two-column layout with the location/map and compact upcoming agenda alongside the weather widget.
- Hourly conditions render in a full-width row below those columns; `WeatherWidget` exposes `showHourly` so the Home composition does not duplicate hourly output.
- The Home agenda combines training sessions and tournaments chronologically, limits the display to the next six events, and links to the complete training and tournament calendars.
- Calendar presentation is shared through reusable React components used by the training calendar, tournament calendar, and Home agenda event cards. Domain-specific status, relationship, timezone, and navigation behavior remains in each adapter.
- Frontend coverage includes weather visibility, Home loading and API behavior, mixed agenda ordering, agenda limits, full-calendar links, shared calendar rendering, and Training/Tournament event navigation. Final automated validation passed 120 test files with 1,101 tests; the production build and `git diff --check` also passed, while ESLint completed with zero errors and five pre-existing unrelated warnings.

## 13. Official references (review before deployment)

- WeatherAPI product and free tier: https://www.weatherapi.com/
- WeatherAPI pricing: https://www.weatherapi.com/pricing
- WeatherAPI terms (attribution and application licensing): https://www.weatherapi.com/terms
- WeatherAPI documentation: https://www.weatherapi.com/docs/
- WeatherAPI Weather Maps: https://www.weatherapi.com/docs/weather-maps/
- Leaflet: https://leafletjs.com/
- Google Maps custom map types: https://developers.google.com/maps/documentation/javascript/maptypes
- OpenStreetMap tile usage policy: https://operations.osmfoundation.org/policies/tiles/
- Open-Meteo terms (free hosted tier is non-commercial): https://open-meteo.com/en/terms
- Open-Meteo pricing and self-host option: https://open-meteo.com/en/pricing
- Australian Bureau of Meteorology: https://www.bom.gov.au/
- Frontend repository: https://github.com/romalopes/beachvolleyballhub_frontend
- Backend repository: https://github.com/romalopes/beachvolleyballhub_api

_Pricing, licensing and quotas were checked against official provider pages on 27 October 2026; recheck before release._
