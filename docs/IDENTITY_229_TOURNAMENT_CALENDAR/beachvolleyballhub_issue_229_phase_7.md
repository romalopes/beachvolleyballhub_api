## 9. Phase 7 — Tournament detail, My Tournaments, self-link

Add `/tournaments/:id` showing organiser, dates/timezone, location, scope, divisions, description, official website, ordered watch links and cancellation notice. Provide a sign-in prompt for guests and authenticated participation form with role and eligible division multi-select. Selection rules: participant/coach can optionally select multiple active divisions; spectator/volunteer/other have no division selection. Existing inactive selections may remain visible but cannot be newly added. Add `/my-tournaments` (or an existing account-dashboard tab if that better fits HEAD), using server-side `mine=1`.

**AI prompt — detail and participation**

Implement tournament detail, self-link/edit/unlink and My Tournaments in the existing React app. Reuse auth context and typed API methods. Resolve Account only on the server. Clearly label participation as personal interest/attendance, NOT official registration. Support multi-division selection and role transitions; preserve archived privacy and allow unlink through the designated endpoint. Handle 401/403/404/409/422 cleanly. Include tests for guests, logged-in users, cancelled/completed events, inactive divisions and API races.

**Gate:** frontend build and integration tests pass; detail and My Tournaments show correct data.