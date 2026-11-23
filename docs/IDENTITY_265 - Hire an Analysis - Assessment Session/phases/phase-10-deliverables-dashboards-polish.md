# Phase 10 — Deliverables, Submitter Dashboard & Guest Polish

**Goal:** Complete submitter-facing dashboard, guest experience polish, and deliverable access.

**Prerequisites:** Phase 9 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Frontend** | `/my/analysis-requests` (list), `/my/analysis-requests/:id` (detail) |
| **Frontend** | Guest access page polish (`/analysis/guest/:token`) |
| **Controller** | Deliverable download (signed URL) |
| **Mailer** | `deliverable_uploaded` notification |
| **Tests** | Dashboard, guest access, deliverable download |

---

## Submitter Dashboard (Authenticated)

- **List** (`/my/analysis-requests`): reference, title, package, workflow_status, payment_status, price, coach, last_activity, unread indicator
- **Detail** (`/my/analysis-requests/:id`): full request info, videos, status timeline, conversation, deliverables (download), assessment links

---

## Guest Access Page (Polished)

- Secure token-based access (already implemented)
- Shows: status, request details, videos (where allowed), messages (read/reply), price/payment info, deliverables
- "Create Account" CTA → claim flow (Phase 7)
- Mobile-responsive

---

## Deliverable Download

```ruby
# GET /api/v1/analysis_requests/:id/deliverables/:document_id/download
def download_deliverable
  doc = @request.analysis_request_documents.find(params[:document_id])
  redirect_to rails_blob_url(doc.file, disposition: "attachment")
end
```

Signed URL with expiry for security.

---

## Delivered Surfaces (frontend, IDENTITY-265 follow-up)

| Surface | Route | Notes |
|---------|-------|-------|
| My analysis requests | `/my/analysis-requests` (`MyAnalysisRequestsPage`) | Pundit-scoped list, status filter, pagination, empty state → `/hire-analysis` |
| Request detail | `/analysis-requests/:id` (`AnalysisRequestDetailPage`) | Summary + videos + deliverables + conversation; staff panel for workflow, internal notes for staff only |
| Notification targets | bell entries use `/analysis-requests/:id` | No more catch-all redirect to Home |
| Sidebar | `My Analysis Requests` in the User group | Signed-in submitters; staff also see `Analysis Requests → Manage Requests` |

Shared display helpers live in `src/utils/analysisRequest.ts` (labels + badge tone + date formatting), and page styles were added to `src/hire-analysis.css` (`.analysis-request-list`, `.analysis-request-row-header`, `ul.selected-videos`).

## Acceptance Criteria

- [x] Authenticated submitter dashboard works (list + detail)
- [x] Guest access page polished, secure, mobile-friendly
- [x] Deliverables downloadable via signed URLs
- [ ] Email notification on deliverable upload (not implemented — out of scope for this slice)
- [x] Status badges show workflow + payment state (timeline view deferred)
- [ ] Unread message indicators (conversation renders inline; no per-message unread counts)
- [x] `bin/rails test` + `npm run test` + `npm run lint` pass for the feature files

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Separate guest page | Reuses `/analysis/guest/:token` from Phase 1 | Single secure endpoint |
| Status timeline | Built from `workflow_status` + `payment_status` badges/timestamps | No separate audit table needed |
| Coach workspace page | Not built; coaches use the shared detail page and the existing `/coach/analysis_requests` API | Keeps one renderer; UI can split later without API changes |
| Message replies | Conversation is read-only in the SPA | The messaging controller was not part of this slice; API shape is ready |