# Phase 4 — Geocoding, Curation and Deduplication

**Status:** Asynchronous geocoding implemented; merge tooling and proximity review remain deferred

## Implemented

- Proposal, verification, rejection-ready and archive/merge lifecycle fields.
- Coordinate provenance and geocoding status fields.
- Coordinate pair/range validation.
- Normalized canonical names and aliases.
- Curator/admin-only canonical edits, verification, archival and Court management.
- Search across canonical names and aliases.
- Provider-independent asynchronous geocoding client with an initial Geoapify adapter.
- Geoapify requests use explicit open/read timeouts, an identifying User-Agent,
  one-result queries and structured transient/permanent errors.
- Successful and no-result lookups are cached through `Rails.cache` for 30 days
  and 24 hours respectively; provider/network failures are not cached.
- `LocationGeocodingJob` runs on the existing Solid Queue `background` queue,
  retries transient failures three times with polynomial backoff, and marks an
  exhausted or permanent failure as `failed` without deleting the proposal.
- Query fingerprints make jobs idempotent: a stale job cannot overwrite a newer
  address. Manual curator coordinates use `geocoding_status: manual` and
  `coordinate_source: manual` and are never overwritten by the worker.
- Ordinary proposal creation never accepts browser-supplied coordinates. When
  geocoding is configured and sufficient venue/address data exists, the saved
  proposal starts as `pending` and is enqueued after persistence.

## Provider configuration

The initial provider is Geoapify, selected because it supports forward
geocoding, place search and a larger free allowance than the public Nominatim
service. The browser never receives the provider API key.

Required production variables on both the web and worker services:

```text
GEOCODING_ENABLED=true
GEOCODING_PROVIDER=geoapify
GEOAPIFY_API_KEY=...
GEOCODING_USER_AGENT=BeachVolleyballHub/1.0 (operations contact)
GEOCODING_OPEN_TIMEOUT=3
GEOCODING_READ_TIMEOUT=5
```

If geocoding is disabled or no API key is configured, proposal creation remains
available and the location stays `not_requested`.

## Nominatim policy note

Public Nominatim remains suitable only as a deliberately enabled low-volume
development adapter. Its usage policy requires an identifying User-Agent,
OpenStreetMap attribution, caching, no autocomplete, and an application-wide
maximum of one request per second. It is not the production default and no
Nominatim adapter is enabled by this phase.

## Deferred prerequisites

- Define confidence thresholds and candidate-review UI.
- Implement transactional merge execution that repoints all defaults, associations, events and Court references with an audit record.
- Add proximity-based duplicate candidates after coordinate coverage exists.

No external call is made synchronously in a user request. Autocomplete is also
deferred so proposal creation is provider-resilient and does not spend one
provider credit per keystroke.