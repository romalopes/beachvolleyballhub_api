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

## Acceptance Criteria

- [ ] Authenticated submitter dashboard works (list + detail)
- [ ] Guest access page polished, secure, mobile-friendly
- [ ] Deliverables downloadable via signed URLs
- [ ] Email notification on deliverable upload
- [ ] Status timeline shows all workflow transitions
- [ ] Unread message indicators work
- [ ] `bin/rails test` + `npm run test` + `npm run lint` pass

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Separate guest page | Reuses `/analysis/guest/:token` from Phase 1 | Single secure endpoint |
| Status timeline | Built from `workflow_status` + `payment_status` timestamps | No separate audit table needed |