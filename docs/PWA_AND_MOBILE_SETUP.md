# Beach Volleyball Hub PWA and Mobile Setup

This guide covers the React/Vite frontend, Rails API, installable PWA, and
Capacitor Android/iOS projects.

## 1. Prerequisites

- Node.js 20 or newer and npm.
- Ruby 3.4.2 and Bundler for the Rails API.
- PostgreSQL 14 or newer.
- Git.
- Android Studio, Android SDK, and an emulator or Android device for Android.
- macOS with Xcode and CocoaPods for iOS.
- Google Play Console and Apple Developer accounts for store distribution.

Check the web projects with:

```bash
node --version
npm --version
ruby --version
bundle --version
```

## 2. Install dependencies

From the repository root:

```bash
cd beachvolleyballhub
npm install

cd ../beachvolleyballhub_api
bundle install
```

Create the local PostgreSQL database using the Rails project's normal setup:

```bash
bin/rails db:prepare
```

Copy each `.env.example` to a local, untracked environment file and fill in
credentials appropriate for the selected environment.

## 3. Environment variables

### Frontend

Create `/Users/romalopes/Documents/studies/my_project/beachvolleyballproject/beachvolleyballhub/.env.local`:

```env
VITE_API_BASE_URL=/api/v1
VITE_GOOGLE_MAPS_EMBED_API_KEY=
```

Local development uses the Vite proxy. For a deployed web app or mobile build,
use a publicly reachable HTTPS API URL, for example:

```env
VITE_API_BASE_URL=https://api.example.com/api/v1
```

Never use `localhost` for a physical device build. `VITE_*` values are bundled
into the browser/app and must not contain private server credentials.

### Backend

Create the Rails environment file from:

```bash
cd beachvolleyballhub_api
cp .env.example .env
```

At minimum, configure the database, `APP_HOST`, `FRONTEND_URL`, and production
`CORS_ORIGINS`/`ALLOWED_HOSTS`. Configure mail, weather, geocoding, storage,
and other optional services only when they are enabled.

## 4. Local web development

Run the API in one terminal:

```bash
cd beachvolleyballhub_api
bin/rails server -p 3001
```

Run the frontend in another:

```bash
cd beachvolleyballhub
npm run dev
```

Open the URL printed by Vite, normally `http://localhost:5174`. Confirm that
the browser can load API data, authenticate, and navigate directly to nested
routes.

## 5. Production PWA deployment

Build the frontend with the production API URL present at build time:

```bash
cd beachvolleyballhub
VITE_API_BASE_URL=https://api.example.com/api/v1 npm run build
```

Deploy the generated `dist/` directory to Vercel, Cloudflare Workers, or
another HTTPS static host. Configure SPA fallback rewrites to `index.html` and
ensure the API allows the deployed origin through CORS. Test:

- HTTPS loading and browser refresh on nested routes.
- PWA install from a supported browser.
- Login, API requests, images, and map embeds.
- Offline/error behavior when the network is unavailable.

The mobile wrapper also consumes `dist/`, so rebuild it whenever the web app
changes.

## 6. Capacitor setup

The project configuration is in `beachvolleyballhub/capacitor.config.ts`.
After a production web build, synchronize native projects:

```bash
cd beachvolleyballhub
npm run build
npx cap sync
npx cap ls
```

If a platform is absent, initialize it once:

```bash
npx cap add android
npx cap add ios
npx cap sync
```

Do not commit local signing credentials or generated secrets. Review native
configuration after Capacitor dependency upgrades.

## 7. Android testing

1. Install Android Studio and the SDK/platform tools.
2. Create or start an emulator, or enable USB debugging on a device.
3. Build and synchronize the web assets.
4. Open the project:

```bash
cd beachvolleyballhub
npx cap open android
```

Run the app from Android Studio on an emulator or connected device. Verify API
access, deep links/routes, keyboard behavior, permissions, rotation, and slow
or disconnected network behavior. Physical devices must use the deployed HTTPS
API URL.

## 8. iOS testing

On macOS with Xcode installed:

```bash
cd beachvolleyballhub
npx cap open ios
```

Select an iPhone Simulator or connected device in Xcode and run the app. For a
physical device, select a valid development team and signing profile. Verify
safe areas, keyboard behavior, permissions, routes, API access, and network
failure states.

## 9. Signing and store release

### Android

- Create a Google Play Console developer account.
- Create a release keystore and store it outside the repository.
- Configure the Android signing configuration in Android Studio/Gradle.
- Increment `versionCode` and `versionName` for each release.
- Build a signed Android App Bundle (`.aab`).
- Upload it to an internal or closed test track before production release.
- Complete the Play listing, privacy declarations, content rating, and data
  safety information.

### iOS

- Enroll in the Apple Developer Program.
- Register the bundle identifier `com.beachvolleyballhub.app` if available.
- Configure a team, certificates, provisioning, app capabilities, and icons.
- Increment the iOS build number for every upload.
- Archive in Xcode and upload to App Store Connect.
- Test with TestFlight before submitting for review.

Keep production API URLs, privacy policy links, support details, and app-store
metadata consistent across both stores.

## 10. Estimated fees

Fees and taxes change by country and provider. Budget for:

- Google Play Console developer registration: commonly a one-time fee.
- Apple Developer Program: commonly an annual membership fee.
- Hosting, PostgreSQL, email, maps, weather, geocoding, storage, and domains:
  provider-dependent recurring or usage-based costs.
- Google Maps and other APIs: billing may be required even when a free tier is
  available.

Confirm current prices directly with Google Play, Apple, and each service
provider before purchase.

## 11. Troubleshooting

| Symptom | Checks |
|---|---|
| API requests fail in production | Confirm `VITE_API_BASE_URL` includes `/api/v1`, uses HTTPS, and was set before `npm run build`. |
| Device cannot reach API | Replace `localhost` with a public HTTPS API hostname; check CORS and TLS. |
| Nested route returns 404 on web | Configure the host's SPA fallback to `index.html`. |
| Native app shows old frontend | Run `npm run build` followed by `npx cap sync`. |
| Android build fails | Open the project in Android Studio and install the required SDK/build tools. |
| iOS build or signing fails | Update Xcode, select the correct team, bundle ID, certificate, and provisioning profile. |
| Maps are blank | Restrict and enable the Maps Embed browser key and include the current origin. |
| Login/session behavior differs on device | Inspect HTTPS, API CORS, cookie/token configuration, and device date/time. |

Before release, run the frontend tests and build, test both native platforms on
real devices, and verify the production API and deployment logs.