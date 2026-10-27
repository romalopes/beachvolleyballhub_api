# Phase-2-Frontend-Integration.md

## Overview
Integrate the Weather Advisor 3-day forecast into the React/TypeScript frontend. This phase focuses on the Home.tsx component that displays the weather card grid and triggers the fetch when location is detected.

## Component Integration
### File: `src/pages/Home.tsx`

#### State Management
Add the following state variables after the existing location state:
```typescript
const [weather, setWeather] = useState(null);
const [weatherLoading, setWeatherLoading] = useState(false);
const [weatherError, setWeatherError] = useState<string | null>(null);
```

#### useEffect for Weather Fetch
Add a new useEffect that triggers weather fetching when location is detected:
```typescript
useEffect(() => {
  let cancelled = false;

  const fetchWeather = async (location: { lat: number; lon: number }) => {
    if (cancelled) return;
    setWeatherLoading(true);
    try {
      const response = await api.weather(location.lat, location.lon);
      setWeather(response);
    } catch (error) {
      setWeatherError(error.message || "Failed to fetch weather");
    } finally {
      setWeatherLoading(false);
    }
  };

  // Trigger when detectedLocation changes
  useEffect(() => {
    if (detectedLocation) {
      fetchWeather({ lat: detectedLocation.lat, lon: detectedLocation.lon });
    }
  }, [detectedLocation]);

  return () => {
    cancelled = true;
  };
}, [detectedLocation, weatherLoading]);
```

#### Weather Card UI
Render a 3-day forecast card grid below the map section:
- **Loading state**: Show spinner or "Loading weather..." message
- **Error state**: Show error message if weather fetch fails
- **Empty state**: No card grid if no weather data
- **Card content**: For each day: date, condition icon, temperature high/low, precipitation chance
- **Responsive layout**: 1 card on mobile, 3 cards on desktop (CSS grid)

#### API Service Layer
Ensure `src/api.ts` or `src/services/api.ts` has the `api.weather(lat, lon)` method:
- **Method**: `api.weather(lat: number, lon: number)`
- **Endpoint**: `GET /api/v1/weather?lat=&lon=`
- **Returns**: Parsed weather forecast data

## Attribution
- Display WeatherAPI attribution below the weather card grid
- Required by WeatherAPI.com free tier terms
- Format: "Weather data provided by WeatherAPI.com"

## Constraints
- **Cost**: $0 free tier only
- **Forecast days**: 3 days
- **Attribution**: WeatherAPI.com attribution required
- **Responsive design**: Cards must work on mobile and desktop
- **Loading/error states**: Must handle all states gracefully