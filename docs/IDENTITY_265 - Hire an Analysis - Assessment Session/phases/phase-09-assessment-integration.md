# Phase 9 — Assessment & Assessment Session Integration

**Goal:** Link AnalysisRequests to existing Assessments and Assessment Sessions for context.

**Prerequisites:** Phase 8 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Model** | `app/models/analysis_request_assessment_session.rb` (join table) |
| **Controller** | Admin/Coach actions to link/unlink |
| **Routes** | Nested on `analysis_requests` |
| **Tests** | Link/unlink, visibility rules |

---

## Join Model

```ruby
# app/models/analysis_request_assessment_session.rb
class AnalysisRequestAssessmentSession < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_assessment_sessions
  belongs_to :assessment_session, inverse_of: :analysis_request_assessment_sessions
  validates :analysis_request_id, uniqueness: { scope: :assessment_session_id }
end
```

Migration: `create_analysis_request_assessment_sessions` (analysis_request_id, assessment_session_id).

---

## Controller Actions (Admin/Coach)

```ruby
# POST /api/v1/analysis_requests/:id/link_assessment_session
def link_assessment_session
  session = AssessmentSession.find(params[:assessment_session_id])
  @request.assessment_sessions << session unless @request.assessment_sessions.include?(session)
  render json: { analysis_request: serialize(@request.reload, detail: true) }
end

# DELETE /api/v1/analysis_requests/:id/assessment_sessions/:assessment_session_id
def unlink_assessment_session
  @request.assessment_sessions.delete(params[:assessment_session_id])
  render json: { analysis_request: serialize(@request.reload, detail: true) }
end
```

Policy: only admin/curator can link/unlink (coach can view).

---

## Visibility Rules

- Admin/Curator: see all linked assessments/sessions
- Coach: see linked sessions for context (read-only)
- Submitter: see only sessions they participated in (via `AssessmentSessionParticipant`)
- Guest: no assessment links visible

---

## Acceptance Criteria

- [ ] Admin can link/unlink Assessment Sessions to requests
- [ ] Linked sessions appear in request detail (per visibility rules)
- [ ] Coach sees linked sessions for context
- [ ] Submitter sees only their relevant sessions
- [ ] `bin/rails test` passes

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Link to Assessment definitions | Only link to Assessment Sessions (which reference definitions) | Sessions are the scheduled events; definitions are templates |
| Bidirectional | `AssessmentSession` gets `analysis_requests` via `has_many :through` | Consistent with existing patterns |
## Addendum (24 Nov 2026): assessment sessions are analysis-owned

The direct analysis_request_assessment_sessions join was removed. Ownership now:

- Analysis has_many :assessment_sessions through analysis_assessment_sessions (the only write path).
- AnalysisRequest#assessment_sessions delegates: analysis ? analysis.assessment_sessions : AssessmentSession.none.
- AssessmentSession has_many :analyses through analysis_assessment_sessions (request-side join + model deleted).
- Migration 20261124100000 copies existing request-side links onto the request analysis (ON CONFLICT DO NOTHING), then drops the join table; down recreates it.
- Request link action resolves the session first (unknown id 404), then requires an analysis (422 otherwise); UI: analysis main panel list + clickable deliverable rows on request/guest pages.
