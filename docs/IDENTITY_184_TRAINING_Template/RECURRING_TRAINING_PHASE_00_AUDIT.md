# RECURRING_TRAINING_PHASE_00_AUDIT.md

## 0. Audit Summary

### 0.1 Current State of Training Sessions

- **Model**: `TrainingSession` in `/app/models/training_session.rb`
  - Fields: `title`, `description`, `starts_at`, `ends_at`, `location`, `status`, `visibility`, `created_by_id`
  - Statuses: `draft`, `scheduled`, `cancelled`, `completed`
  - Visibilities: `shared`, `private`
  - No recurrence-related fields exist
  - No organization/group relationship (training sessions are independent resources)

- **API**: 
  - `/api/v1/training_sessions` - standard CRUD with manager-only create/update/destroy
  - Index route filters by status, date range, etc.
  - Show route returns full details

- **Frontend**:
  - `TrainingFormPage` for creating/editing sessions
  - `Training` page for viewing sessions
  - No recurrence UI elements exist
  - Only managers can create new sessions (button labeled "New Training")

- **Authorization**:
  - `ContentAuthorization` module exists
  - `require_training_manager!` used for create/update/destroy actions
  - No row-level organization/group RBAC for training sessions

### 0.2 What Needs to Be Implemented

1. **Data Model Changes**:
   - Add `training_series_id` (optional) to `TrainingSession`
   - Add `recurrence_key` (string) for identifying recurrence pattern
   - Add `original_starts_at` (datetime) to capture the original start time
   - Add `override_fields` (jsonb) to store fields that override the series defaults
   - Add `cancellation_reason` and `cancelled_at` for cancellation tracking
   - Add organization/group relationships with nullification

2. **New Tables**:
   - `training_templates`: reusable training configurations
   - `training_series`: recurrence definition + defaults snapshot

3. **New Services**:
   - `TrainingSeriesPreview`: dry run validation
   - `TrainingSeriesGenerator`: create occurrences from series
   - `TrainingSeriesCreator`: create series from template + recurrence
   - `TrainingSeriesCanceller`: bulk cancel explicit sessions
   - `TrainingSeriesStopper`: stop generation
   - `TrainingSeriesFutureEditor`: apply overrides to future sessions
   - `TrainingSeriesSplitter`: split series at boundary
   - `TrainingSessionCancellationNotifier`: send cancellation notifications

4. **API Changes**:
   - New endpoints for templates, series, and bulk operations
   - Feature flag `RECURRING_TRAINING_ENABLED`
   - Update existing `TrainingSessionsController` to handle new fields

5. **Frontend Changes**:
   - New components for recurrence configuration
   - Enhanced series detail view with bulk actions
   - Dashboard for series management

### 0.3 Constraints & Assumptions

- **No data migration**: All changes are additive; no backfill required
- **Feature flag**: `RECURRING_TRAINING_ENABLED` defaults to enabled after deploy
- **No location model**: `location` remains string; `location_detail` added for future use
- **Organizational scope**: Row-level org/group RBAC is deferred to Phase 8 (RBAC issue)

### 0.4 Success Criteria for Phase 0

- [x] Audit documentation completed
- [x] ADR documented with architecture decisions
- [x] All files referenced in the implementation plan are created
- [x] Phase 0 itself made no code changes (documentation only)