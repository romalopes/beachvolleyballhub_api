# Phase 0 - Audit and Baseline

## Purpose

Document the existing implementation before making changes to ensure we understand:

1. Current architecture and file structure
2. Existing Weather Advisor implementation
3. Current cache strategy
4. Authentication behavior
5. Frontend integration points
6. Plan deviations from original specifications

## Repository Structure

### Backend (beachvolleyballhub_api)

- **Weather Advisor**: `app/services/weather/volleyball_advisor.rb`
  - Contains fixed factor weights (`WEIGHTS`)
  - `assess(current:, rain_chance_percent:)` method
  - Currently called by `WeatherApi.fetch_forecast` at line 59

- **Weather API Service**: `app/services/weather_api.rb`
  - `fetch_forecast(latitude, longitude, api_key:, http_class:, cache:)`
  - Caches entire payload including `volleyball` assessment
  - Cache key: `weather/v3/{rounded-latitude},{rounded-longitude}/days-3`
  - TTL: 900 seconds (configurable via `WEATHER_CACHE_TTL_SECONDS`)

- **Weather Controller**: `app/controllers/api/v1/weather_controller.rb`
  - Public endpoint `GET /api/v1/weather`
  - Uses `resume_session` from `Api::V1::ApplicationController`
  - `Current.user&.account` available for authenticated requests

- **Account Model**: `app/models/account.rb`
  - Has `has_one :notification_preference, dependent: :destroy`
  - No existing `weather_advisor_preference` association

- **Tests**: 
  - Minitest framework
  - `test/controllers/api/v1/weather_controller_test.rb` 
  - `test/services/weather/volleyball_advisor_test.rb`

### Frontend (beachvolleyballhub)

- **Account Page**: `src/pages/Account.tsx`
  - Contains `<NotificationPreferencesPanel />` component
  - Ends with `<WeatherWidget />` component
  - Has commented-out configuration link area near line 166

- **Weather Widget**: `src/components/weather/WeatherWidget.tsx`
  - Displays `volleyball` assessment from server
  - Contains commented-out `<Link to="/account">` at line 166
  - Uses `WeatherApi` for weather data

- **API Client**: `src/api.ts`
  - `fetchAPI` and `postJSON` helpers
  - `api.weather` and `api.notificationPreferences` methods
  - `API_BASE_URL = "/api/v1"`

- **Authentication**: `src/auth/AuthContext.tsx`
  - `useAuth()` returns `{ user }`
  - No direct auth usage in WeatherWidget currently

- **Tests**: 
  - Vitest + Testing Library
  - Two unrelated `Home.test.tsx` failures exist

## Current Implementation Details

### Weather Advisor Scoring

- Uses fixed weights from `WEIGHTS` constant:
  - Wind: 40%
  - Temperature: 20%
  - Rain: 25%
  - UV: 5%
  - Humidity: 10%

- Warnings and safety overrides are separate from normal scoring
- Score calculation is server-side only

### Cache Strategy

- Shared cache key for all users at same location
- Contains personalized `volleyball` assessment
- Risk: One user's personalized score could be served to another user

### Authentication

- Public weather endpoint works for guests
- Authenticated users can have personalized scores
- `Current.user&.account` available on public weather route

## Plan Deviations

1. **Testing Framework**: Plan specifies RSpec, but project uses Minitest
2. **Repository Name**: Plan says `beachvolleyballhub_frontend`, actual repo is `beachvolleyballhub`
3. **Cache Isolation**: Plan describes query cache isolation, but actual implementation uses server-side cache
4. **nouislider**: Plan assumes this dependency exists, but it's not currently installed
5. **Scope**: Plan includes optional score preview endpoint, which we will exclude

## Documentation Requirements

- Create one Markdown file per phase in `docs/IDENTITY_253_Weather Preferences Configure/`
- Update original plan with links to each phase document
- Document completion status for each phase