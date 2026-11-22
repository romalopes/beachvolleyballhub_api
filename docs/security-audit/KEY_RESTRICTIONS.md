# Key restrictions runbook (SEC-02)

The Google Maps **Embed** API key (`VITE_GOOGLE_MAPS_EMBED_API_KEY`) is a public
browser key: it is inlined into the web bundle (`dist/assets/*.js`) and the
Capacitor Android/iOS bundles. It cannot be hidden, so its safety depends
entirely on **GCP key restrictions**. Without them, any third party can embed
the key on their own site and drain this project's Maps quota and billable usage.

## 1. Restrict the key (Google Cloud Console → APIs & Services → Credentials)

Application restrictions → **HTTP referrers (web sites)** **and** mobile apps:

- `https://beachvolleyballhub.com/*`
- `https://www.beachvolleyballhub.com/*`
- `https://beachvolleyballhub.romalopes.workers.dev/*`
- `https://*-beachvolleyballhub.romalopes.workers.dev/*` (Workers previews)
- Android apps: package name + SHA-1 signing-cert fingerprint
- iOS apps: bundle identifier

API restrictions → **Restrict key** → enable **only** `Maps Embed API`.

## 2. Protect spend

- Set a **quota limit** on the Maps Embed API and a **budget + alert** in Billing
  so the key cannot silently run up cost.

## 3. Rotation

- Create a new restricted key, deploy it (web + both mobile bundles), verify Maps
  renders, then delete the old key.

## 4. Verify

- From an unapproved origin, an embed request must be rejected by Google
  ("This page didn't load Google Maps correctly" / 403 `RefererNotAllowed`).
- The app must still render the graceful fallback ("Map preview is unavailable"
  + "Open in Google Maps") when the key is absent — see
  `src/components/locations/LocationMap.tsx`.

> The key is never committed to source (the mobile bundles are build artifacts),
> so no repository change is required beyond this runbook and the `.env.example`
> note. This is an operational sign-off item.
