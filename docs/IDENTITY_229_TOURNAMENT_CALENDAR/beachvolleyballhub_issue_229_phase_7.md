## 9. Phase 7 — Tournament detail, My Tournaments, self-link

Add `/tournaments/:id` showing organiser, dates/timezone, location, scope, divisions, description, official website, ordered watch links and cancellation notice. Provide a sign-in prompt for guests and authenticated participation form with role and eligible division multi-select. Selection rules: participant/coach can optionally select multiple active divisions; spectator/volunteer/other have no division selection. Existing inactive selections may remain visible but cannot be newly added. Add `/my-tournaments` (or an existing account-dashboard tab if that better fits HEAD), using server-side `mine=1`.

**AI prompt — detail and participation**

Implement tournament detail, self-link/edit/unlink and My Tournaments in the existing React app. Reuse auth context and typed API methods. Resolve Account only on the server. Clearly label participation as personal interest/attendance, NOT official registration. Support multi-division selection and role transitions; preserve archived privacy and allow unlink through the designated endpoint. Handle 401/403/404/409/422 cleanly. Include tests for guests, logged-in users, cancelled/completed events, inactive divisions and API races.

### Implementation status — October 15, 2026

Implemented across the API and React client:

- Detail now shows timezone-aware dates, organiser/location/website, ordered active watch links, divisions, cancellation and ended-event notices.
- Guests receive a sign-in action which preserves the tournament detail return path. Authenticated users can add, update, or idempotently remove their own participation; the UI explicitly states this is not official registration.
- The current backend role contract is `player`, `coach`, `referee`, and `organiser`. Optional multi-division selection is offered for `player` and `coach`; referee/organiser submissions send no divisions.
- Inactive divisions are displayed for retained selections, cannot be newly selected in the UI, and are rejected server-side if a forged/new inactive ID is submitted.
- `/my-tournaments` is authenticated, uses server-side `mine=1`, excludes archived records, and groups returned tournaments into Upcoming, Ongoing, and Past sections.
- The participation endpoint now consistently requires authentication, loads the requested tournament, accepts the typed `{ participation: ... }` payload, exposes `division_ids` and `my_participation`, and fixes the `Current_user` typo in `mine=1` processing.

**Verification note:** focused frontend API/directory tests pass. Full frontend typecheck remains blocked by the pre-existing `ConfigurationSettings.test.tsx` configuration-shape failures documented in Phase 9. Rails test execution is currently blocked before assertions by the existing test-database connection/fixture foreign-key failures; this is also a Phase 9 environment/fixture repair item.