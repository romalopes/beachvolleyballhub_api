# Phase 4 — Manual Invoice/Payment Tracking & Payment Gate

**Goal:** Track invoices sent, payments received, overdue status; enforce "payment before work" gate with admin override.

**Prerequisites:** Phase 3 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Model** | `app/models/analysis_request_invoice.rb` |
| **Controller** | Add `mark_invoice_sent`, `mark_paid`, `mark_overdue`, `mark_refunded` to admin/main controllers |
| **Policy** | `mark_invoice_sent?`, `mark_paid?`, `mark_overdue?`, `mark_refunded?` in `AnalysisRequestPolicy` |
| **Routes** | Member actions on `analysis_requests` |
| **Jobs** | `app/jobs/analysis_request_overdue_check_job.rb` (daily) |
| **Notifications** | `Notifications::WorkflowEvents` events for invoice/payment |
| **Mailers** | `AnalysisRequestsMailer` invoice_sent, payment_received, overdue_reminder |
| **Tests** | Model/controller tests for invoice/payment transitions |

---

## Model: `AnalysisRequestInvoice`

```ruby
# app/models/analysis_request_invoice.rb
class AnalysisRequestInvoice < ApplicationRecord
  belongs_to :analysis_request
  has_one_attached :file # PDF invoice

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[AUD] }
  validates :sent_at, presence: true
  validates :status, inclusion: { in: %w[sent paid overdue cancelled refunded] }

  scope :unpaid, -> { where(status: "sent") }
  scope :overdue, -> { unpaid.where("sent_at < ?", 30.days.ago) }
end
```

Migration: `create_analysis_request_invoices` with `analysis_request_id`, `amount_cents`, `currency`, `sent_at`, `status`, `external_reference`, `file` attachment.

---

## Controller Actions

```ruby
# Admin/Main controller member actions
def mark_invoice_sent
  @request.analysis_request_invoices.create!(
    amount_cents: @request.price_cents,
    currency: "AUD",
    sent_at: Time.current,
    status: "sent",
    external_reference: params[:external_reference]
  )
  @request.mark_invoice_sent!
  notify_invoice_sent(@request)
  render json: { analysis_request: serialize(@request.reload, detail: true) }
end

def mark_paid
  invoice = @request.analysis_request_invoices.unpaid.first
  invoice&.update!(status: "paid", paid_at: Time.current)
  @request.mark_paid!
  notify_payment_received(@request)
  render json: { analysis_request: serialize(@request.reload, detail: true) }
end

def mark_overdue
  @request.analysis_request_invoices.unpaid.update_all(status: "overdue")
  @request.update!(payment_status: "overdue")
  notify_overdue(@request)
  render json: { analysis_request: serialize(@request.reload, detail: true) }
end

def mark_refunded
  @request.update!(payment_status: "refunded", workflow_status: "cancelled")
  render json: { analysis_request: serialize(@request.reload, detail: true) }
end
```

---

## Payment Gate Enforcement

```ruby
# In AnalysisRequest#start_work!
def start_work!
  if payment_status != "paid" && payment_status != "complimentary"
    errors.add(:base, "Payment required before work can start")
    raise ActiveRecord::RecordInvalid, self
  end
  update!(workflow_status: "in_progress", work_started_at: Time.current)
end

# Admin override (permission-controlled)
def start_work_with_override!(reason)
  raise "Unauthorized" unless Current.user.admin? || Current.user.curator?
  update!(workflow_status: "in_progress", work_started_at: Time.current,
          payment_override: true, payment_override_reason: reason)
  LogService.log("payment_override", analysis_request: self, reason: reason)
end
```

---

## Overdue Check Job

```ruby
# app/jobs/analysis_request_overdue_check_job.rb
class AnalysisRequestOverdueCheckJob < ApplicationJob
  queue_as :default

  def perform
    AnalysisRequest.where(payment_status: "invoice_sent")
                   .where("invoice_sent_at < ?", 30.days.ago)
                   .find_each do |req|
      req.update!(payment_status: "overdue")
      Notifications::WorkflowEvents.analysis_request_overdue(req)
      AnalysisRequestsMailer.overdue_reminder(req).deliver_later
    end
  end
end
```

Schedule in `config/schedule.yml` (sidekiq-cron or solid_queue recurring): daily.

---

## Delivered: invoice PDF email + ledger (IDENTITY-265 follow-up)

| Piece | File | Notes |
|-------|------|-------|
| PDF generator | `app/services/invoices/pdf_document.rb` | Dependency-free PDF 1.4 writer (no Prawn/wkhtmltopdf in this repo). One A4 page, Helvetica, computed xref offsets; `Quick Look` renders it and `pdf_document_test.rb` verifies offsets. |
| Invoice logo | `app/services/invoices/logo_image.rb` | `public/ball.png` embedded as an image XObject in the header. The shipped file is a 512×512 JPEG (despite the name), embedded verbatim with `/DCTDecode`; real PNGs are decoded to RGB (`/FlateDecode`), alpha composited onto white. Unsupported/missing logo degrades to a text-only header. |
| Invoice numbering | `AnalysisRequestInvoice#number` | `INV-####` derived from the row id (unique/stable; no sequence table). |
| Email | `AnalysisRequestsMailer#invoice_to_submitter` + text/HTML views | PDF attached as `INV-####.pdf`, subject `Invoice INV-#### for analysis request ANL-…`; paid invoices say no action is needed. |
| Delivery job | `AnalysisRequestInvoiceEmailJob` | Sends, sets `emailed_at`, marks invoice `sent` (unless paid), moves request to `invoice_sent` (never downgrades `paid`). Re-sending is intentional. |
| Request action | `POST /api/v1/analysis_requests/:id/email_invoice` | Staff-only; creates the invoice from `price_cents` when none exists; 422 when the request has no price; returns 202. |
| Ledger API | `GET /api/v1/admin/invoices` | Filters: `status` (incl. `unpaid` and derived `overdue`), `q` (request reference/title, submitter name/email, external reference), `from`/`to` issue dates, `overdue=1`, pagination; returns filtered `totals`. `POST /api/v1/admin/invoices/:id/email` sends one specific invoice. |
| Ledger UI | `/settings/invoices` (`Invoices.tsx`) | Status tabs, search, date range, “Over 30 days”, totals pill, per-row “Email PDF”, links to the request detail. Card added to the Settings dashboard. |
| Request detail | `/analysis-requests/:id` | Staff panel gained “Email invoice (PDF)” with a confirmation notice. |

## Acceptance Criteria

- [x] Invoice model + migration works (`emailed_at` added)
- [x] Admin can mark invoice sent, marks payment_status=invoice_sent
- [x] Admin can email the invoice as a PDF attachment
- [x] Admin can mark paid → payment_status=paid, auto-starts work if awaiting_payment
- [ ] Overdue job runs daily, marks overdue, sends notifications/emails (derived “overdue” view only)
- [ ] Payment gate: `start_work!` fails if not paid/complimentary
- [x] Invoice ledger with filters + totals (`/settings/invoices`)
- [ ] Refund/cancel transitions work (model statuses exist; no API action yet)
- [x] `bin/rails test` passes (PDF, mailer, job, ledger controller, request action)

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Separate Invoice model | Added `AnalysisRequestInvoice` for audit trail | Plan said "manual invoicing outside BVB" but tracking needs persistence |
| Overdue job | Derived `overdue` filter (sent + older than 30 days) instead of a scheduled mutation | No scheduler wiring in this slice; the ledger still surfaces the right rows |
| PDF generation | Hand-written PDF instead of a gem | Repository has no PDF library and no native binary dependency should be introduced for one invoice |
| Invoice number | Row-id based `INV-####` | Avoids a sequence table; ids are already unique and never reused |