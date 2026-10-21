# Recurring Training — Documentation

Implementation of IDENTITY-184: reusable training templates and weekly recurring
training series for BeachVolleyballHub.

## Document map

| Document | Purpose |
|---|---|
| [`BeachVolleyballHub_Recurring_Training_Implementation_Plan.md`](BeachVolleyballHub_Recurring_Training_Implementation_Plan.md) | Original plan + live implementation status and Phase 0 adaptations |
| [`RECURRING_TRAINING_PHASE_00_AUDIT.md`](RECURRING_TRAINING_PHASE_00_AUDIT.md) | Verified state of the API/SPA before coding |
| [`RECURRING_TRAINING_PHASE_00_ADR.md`](RECURRING_TRAINING_PHASE_00_ADR.md) | Architecture decision, semantics, schema decisions, rollback |
| Phase 1–9 documents | Created/updated as each phase completes (see status below) |
| [`RECURRING_TRAINING_API.md`](RECURRING_TRAINING_API.md) | Request/response contract (Phase 4) |
| [`RECURRING_TRAINING_USER_GUIDE.md`](RECURRING_TRAINING_USER_GUIDE.md) | Coach-facing guide (Phase 9) |

## Phase status

| Phase | Status | Evidence |
|---|---|---|
| 0 — Audit & ADR | ✅ Complete | Audit + ADR + README + plan status table |
| 1 — Data model | ✅ Complete | 3 migrations, models, 59 model tests (0 failures) — [`RECURRING_TRAINING_PHASE_01_DATA_MODEL.md`](RECURRING_TRAINING_PHASE_01_DATA_MODEL.md) |
| 2 — Recurrence & preview | ✅ Complete | Pure expander + preview; 19 tests (0 failures) — [`RECURRING_TRAINING_PHASE_02_RECURRENCE_AND_PREVIEW.md`](RECURRING_TRAINING_PHASE_02_RECURRENCE_AND_PREVIEW.md) |
| 3 — Generation | ✅ Complete | Idempotent generator + transactional creator; 15 tests (0 failures) — [`RECURRING_TRAINING_PHASE_03_GENERATION.md`](RECURRING_TRAINING_PHASE_03_GENERATION.md) |
| 4 — API & authorization | ✅ Complete | Templates/series endpoints, feature flag, 82 request tests (0 failures) — [`RECURRING_TRAINING_PHASE_04_API_AND_AUTHORIZATION.md`](RECURRING_TRAINING_PHASE_04_API_AND_AUTHORIZATION.md) |
| 5 — Frontend creation | ✅ Complete | Template/series forms + preview; tournament-style directory with list/calendar toggle; 20 new tests; full SPA suite 923 passing — [`RECURRING_TRAINING_PHASE_05_FRONTEND_CREATION.md`](RECURRING_TRAINING_PHASE_05_FRONTEND_CREATION.md) |
| 6 — Series dashboard | ✅ Complete | Bulk cancel/delete, stop, cancel future + dashboard — [`RECURRING_TRAINING_PHASE_06_SERIES_DASHBOARD.md`](RECURRING_TRAINING_PHASE_06_SERIES_DASHBOARD.md) |
| 7 — Overrides & splitting | ✅ Complete | Update-future, split, blockers, override preservation — [`RECURRING_TRAINING_PHASE_07_OVERRIDES_AND_SPLITTING.md`](RECURRING_TRAINING_PHASE_07_OVERRIDES_AND_SPLITTING.md) |
| 8 — Notifications & audit | ✅ Complete | Cancellation email job + dedup + LogService audit — [`RECURRING_TRAINING_PHASE_08_NOTIFICATIONS_AUDIT_OBSERVABILITY.md`](RECURRING_TRAINING_PHASE_08_NOTIFICATIONS_AUDIT_OBSERVABILITY.md) |
| 9 — QA & rollout | ✅ Complete | 217 targeted backend tests, 923 frontend tests, rollout/rollback + user guide — [`RECURRING_TRAINING_PHASE_09_QA_AND_ROLLOUT.md`](RECURRING_TRAINING_PHASE_09_QA_AND_ROLLOUT.md) |

Each phase document records: scope, decisions, files changed, migrations, API
contract changes, test evidence (actual command output), limitations, rollback
notes.

## Verified baseline (Phase 0)

- **API:** Rails 8.1 / Ruby 3.4.2. `TrainingSession` has `title`, `description`,
  `starts_at`, `ends_at`, `location` (string), `status`, `visibility`,
  `created_by_id`; no recurrence fields, no template/series tables.
- **Authorization:** `ContentAuthorization#require_training_manager!` →
  `Current.user.content_manager?`. Training management is role-based, not
  creator- or organisation-scoped.
- **Related models:** `Organisation`, `Group` (optional organisation), `GroupMembership`
  (polymorphic Account/Profile), `CoachProfile` (optional account).
- **Location:** no `Location`/`Court` model; those fields are reserved for a
  future issue.
- **Time zone:** no `config.time_zone`, so UTC is the default; series store an
  explicit IANA zone.
- **API conventions:** `render json:` with `only:`/`include:`, `{ errors: [] }`
  for 422, `{ error: "" }` for auth failures, paginated lists as
  `{ data, meta: { page, per_page, total, total_pages } }`.
- **SPA:** React 19 + Vite + TypeScript + vitest. Training pages live under
  `ManagerRoute`; client calls are centralised in `src/api.ts`.

## Architecture in one picture

```
Organisation ─┬─ TrainingTemplate ── TrainingSeries ── TrainingSession (0..N)
Group ────────┘         │                  │                │
CoachProfile ───────────┘                  │                └─ participants / attendance / assessments
                                           └─ recurrence + immutable defaults snapshot
```

- `training_sessions.training_series_id` is **nullable**: existing and manual
  sessions need no migration.
- A cancelled occurrence keeps its `recurrence_key` (tombstone) so regeneration
  cannot resurrect it.
- Generated sessions are `scheduled`; no participants are created automatically.

## Training directory (SPA)

`/training` is the single directory: a **List / Calendar toggle** switches views
in place, calendar mode adds month/week ranges and period navigation, and the
filters live in a tournament-style aside. `/calendar` redirects to
`/training?view=calendar`. Templates and series directories use the same
header-actions + filter-aside + card-grid layout. See
[`RECURRING_TRAINING_PHASE_05_FRONTEND_CREATION.md`](RECURRING_TRAINING_PHASE_05_FRONTEND_CREATION.md).

## Known limitations (documented, deliberate)

- Organisation/group **row-level** RBAC for trainings does not exist; V1 mirrors
  the existing role-based rule. `organisation_id`/`group_id` are metadata.
- `location` remains a string; `location_detail` is added. `location_id`/`court_id`
  arrive with the Location feature.
- `capacity` is stored/displayed but not enforced when adding participants.
- Generation is synchronous and capped at 200 occurrences / 366 days.
- Splitting refuses when future occurrences already have participants.
- Cancellation email is best-effort and deduplicated per participant.

## Verification commands

```bash
cd beachvolleyballhub_api
bin/rails db:migrate
bin/rails test
bin/rubocop

cd ../beachvolleyballhub
npm test
npm run lint
npm run build
```
