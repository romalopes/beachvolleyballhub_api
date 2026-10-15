## 6. Phase 4 — Rails API and authorization
**Status:** ✅ COMPLETED

Proposed routes under `/api/v1`:

| Method            | Route                                           | Behavior                                                            |
| ----------------- | ----------------------------------------------- | ------------------------------------------------------------------- |
| GET               | `/tournaments`                                  | paginated directory/calendar search                                 |
| GET               | `/tournaments/options`                          | scopes, schemes, ordered levels, participation roles                |
| GET               | `/tournaments/:id`                              | detail, safe organiser summary, divisions, links, own participation |
| POST/PATCH/DELETE | `/tournaments[/:id]`                            | admin CRUD, delete unused only                                      |
| POST              | `/tournaments/:id/cancel`                       | admin cancellation                                                  |
| POST              | `/tournaments/:id/archive`                      | admin archive                                                       |
| POST              | `/tournaments/:id/restore`                      | admin restore                                                       |
| POST/PATCH/DELETE | `/tournaments/:id/divisions[/:division_id]`     | admin division management                                           |
| POST/PATCH/DELETE | `/tournaments/:id/watch_links[/:watch_link_id]` | admin watch-link management                                         |
| POST/PATCH        | `/tournaments/:id/participation`                | authenticated Account upsert                                        |
| DELETE            | `/tournaments/:id/participation`                | idempotent self-unlink                                              |

Keep `options` ahead of dynamic ID routing. Inherit existing API base controller and private TestAccess gate. Public detail must expose only a minimal organiser summary, never member rosters, emails or contact details. `my_participation` is null for guests. `mine=1` requires login. Admin authority uses existing real-user impersonation semantics; self-service uses effective `Current.user.account`. Handle legacy Users without Accounts with a clear error. Reject foreign division IDs and forged account ownership. Do not grant admin permissions to tournament-role `coach`.

**AI prompt — API**

Implement Phase 4 Rails API controllers/routes using the actual app's Api::V1::ApplicationController, authorization, error envelopes, JSON methods, pagination, private TestAccess gate, and Current.user/Current.real_user semantics. Reuse the services and query object. Avoid introducing Pundit/ActiveModelSerializers unless already installed. Add comprehensive Minitest request tests for guest, owner, coach, curator, admin, impersonation, malformed inputs, archive privacy, cross-tournament division attacks, and duplicate requests. Update OpenAPI/API documentation if present. Show exact endpoint examples and test output.

**Gate:** API tests pass and integration with Phase 3 verified.