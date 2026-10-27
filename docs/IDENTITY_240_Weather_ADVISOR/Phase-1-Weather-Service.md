# Phase-1-Weather-Service.md

## Overview
Implement the Weather Advisor 3-day forecast service using WeatherAPI.com Free tier. This phase focuses on the backend Ruby on Rails service that fetches and provides weather data to the frontend.

## API Service
- **File**: `app/services/weather_api.rb`
- **Method**: `fetch_forecast(lat, lon)` 
- **Endpoint**: `GET /api/v1/weather?lat=&lon=`
- **Response**: 3-day forecast JSON from WeatherAPI.com

## Backend Implementation
### Controller
- **File**: `app/controllers/api/v1/weather_controller.rb`
- **Action**: `show`
- **Authentication**: Checks for `WEATHERAPI_API_KEY` in environment variables
- **Response**: Returns 3-day forecast data or error status

### Routes
- **File**: `config/routes.rb`
- **Route**: `get "weather", to: "weather#show"`
- **Purpose**: Exposes the weather API endpoint

### Environment Configuration
- **File**: `.env.example`
- **Variable**: `WEATHERAPI_API_KEY=your_weatherapi_key_here`
- **Usage**: Placeholder for the API key - never commit actual keys

### Constraints
- **Cost**: $0 free tier only
- **Forecast days**: 3 days maximum (WeatherAPI.com free tier)
- **Attribution**: Required - must display WeatherAPI attribution
- **Key security**: API key must not be committed to source code; use Rails credentials or `.env`

## API Contract
- **Request**: `GET /api/v1/weather?lat=<number>&lon=<number>`
- **Response**: JSON with 3-day forecast data
- **Error handling**: 401 if API key missing/invalid, 422 for bad coordinates, 500 for service errors