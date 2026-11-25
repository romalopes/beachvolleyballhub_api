# Phase 10: Audit Logging

## Summary
Implemented audit logging for assessment session visibility changes and share link operations using the existing `LogService` infrastructure. Audit logs capture creation, updates (including visibility changes), share link regeneration, and destruction of assessment sessions.

## Files Modified

### Backend (beachvolleyballhub_api)
| File | Purpose |
|------|---------|
| `app/controllers/api/v1/assessment_sessions_controller.rb` | Added audit logging callbacks for create, update, regenerate_share_link, and destroy actions |

## Implementation Details

### Audit Logging Actions
1. **Session Creation** (`create` action):
   - Logs: "Created assessment session \"{name}\""
   - Action: `create`
   - Uses `LogService.log` with session object

2. **Session Updates** (`update` action):
   - If visibility changes: "Changed assessment session \"{name}\" visibility from {old} to {new}"
     - Action: `update_visibility`
   - If other fields change: "Updated assessment session \"{name}\""
     - Action: `update`
   - Uses `before_action :track_visibility_before_update` to capture previous visibility

3. **Share Link Regeneration** (`regenerate_share_link` action):
   - Logs: "Regenerated share link for assessment session \"{name}\""
   - Action: `regenerate_share_link`
   - Only for unlisted sessions (as enforced by policy)

4. **Session Destruction** (`destroy` action):
   - Logs: "Deleted assessment session \"{name}\""
   - Action: `destroy`
   - Captures session name before destruction

### LogService Integration
- Uses existing `LogService.log` centralized audit logging
- Captures: user, request method, path, request_id, IP address, user agent, response status
- Associates log with the assessment session object via `LogObject` polymorphic association
- Respects `AppSetting.logs_enabled?` master switch
- Never raises — logging failures are caught and logged to Rails logger only

### Security Considerations
- Raw share tokens are never logged (only the action description)
- Unauthenticated `show_by_share_token` endpoint does not generate audit logs (no user context)
- Audit logging respects the global `logs_enabled` configuration toggle

### Controller Changes
```ruby
# Track visibility before update
before_action :track_visibility_before_update, only: :update

# In update action:
previous_visibility = @visibility_before_update
if @assessment_session.update(session_params)
  log_session_update(@assessment_session, previous_visibility)
  # ...
end

# In regenerate_share_link:
log_share_link_regeneration(@assessment_session)

# In destroy:
session_name = @assessment_session.name
@assessment_session.destroy!
log_session_destruction(@assessment_session)
```

## Testing
- All existing controller tests pass (28 tests, 75 assertions)
- All policy tests pass (28 tests)
- All model tests pass (27 tests)
- Full test suite: 2179 runs, 8557 assertions, 2 pre-existing unrelated failures
- Manual verification: Audit logs created for visibility changes and share link operations

## Acceptance Criteria Met
- [x] Audit log entry created when session visibility is changed
- [x] Audit log entry created when share link is regenerated
- [x] Audit log entry created when session is created
- [x] Audit log entry created when session is deleted
- [x] Uses existing LogService infrastructure
- [x] Does not log raw share tokens
- [x] Respects global logs_enabled configuration
- [x] All existing tests pass
- [x] No breaking changes to API responses