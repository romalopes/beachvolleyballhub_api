# Phase 3 — Admin/Curator Review, Accept/Reject, Quote & Coach Assignment

**Goal:** Admin/curator workflow actions on AnalysisRequests: list with filters, accept/reject with quote, coach assignment.

**Prerequisites:** Phase 2 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Controller** | `app/controllers/api/v1/admin/analysis_requests_controller.rb` |
| **Controller** | Add member actions to `AnalysisRequestsController` |
| **Policy** | Update `AnalysisRequestPolicy` (already has accept?, reject?, etc.) |
| **Routes** | `config/routes.rb` (admin namespace + member actions) |
| **Notifications** | `app/services/notifications/workflow_events.rb` (new events) |
| **Mailers** | `app/mailers/analysis_requests_mailer.rb` |
---

## Admin Controller (JSON for SPA)

```ruby
# app/controllers/api/v1/admin/analysis_requests_controller.rb
module Api
  module V1
    module Admin
      class AnalysisRequestsController < ApplicationParams
        before_action :authenticate_user!
        before_action :authorize_admin!
        before_action :set_request, only: [:show, :accept, :reject, :quote, :assign_coach, :add_internal_note]

        # GET /api/v1/admin/analysis_requests
        def index
          requests = policy_scope(AnalysisRequest).ordered
          requests = requests.where(workflow_status: params[:status]) if params[:status].present?
          requests = requests.where(payment_status: params[:payment_status]) if params[:payment_status].present?
          requests = requests.where(assigned_coach_profile_id: params[:coach_id]) if params[:coach_id].present?
          requests = requests.where("reference ILIKE ?", "%#{params[:q]}%") if params[:q].present?

          page = (params[:page] || 1).to_i
          per = (params[:per] || 20).to_i.clamp(1, 100)
          requests = requests.page(page).per(per)

          render json: {
            data: requests.map { |r| serialize(r, detail: true) },
            meta: { current_page: page, total_pages: requests.total_pages, total_count: requests.total_count }
          }
        end

        # GET /api/v1/admin/analysis_requests/:id
        def show
          render json: { analysis_request: serialize(@request, detail: true, include_internal: true) }
        end

        # POST /api/v1/admin/analysis_requests/:id/accept
        def accept
          price_cents = params[:price_cents]&.to_i || @request.package&.price_cents || 0
          @request.accept!(price_cents: price_cents)
          notify_acceptance(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        # POST /api/v1/admin/analysis_requests/:id/reject
        def reject
          reason = params[:reason]
          return render json: { errors: ["Rejection reason required"] }, status: :unprocessable_entity if reason.blank?
          @request.reject!(reason)
          notify_rejection(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        # POST /api/v1/admin/analysis_requests/:id/quote
        def quote
          price_cents = params[:price_cents]&.to_i
          return render json: { errors: ["Price required"] }, status: :unprocessable_entity unless price_cents&.>= 0
          @request.quote!(price_cents)
          notify_quote(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        # POST /api/v1/admin/analysis_requests/:id/assign_coach
        def assign_coach
          coach = CoachProfile.find(params[:coach_profile_id])
          @request.update!(assigned_coach_profile: coach)
          notify_coach_assignment(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        # POST /api/v1/admin/analysis_requests/:id/internal_notes
        def add_internal_note
          note = @request.analysis_request_internal_notes.create!(
            body: params[:body],
            account: current_user.account
          )
          render json: { internal_note: serialize_internal_note(note) }
        end

        private

        def authorize_admin!
          head :forbidden unless current_user.admin? || current_user.curator?
        end

        def set_request
          @request = AnalysisRequest.find(params[:id])
        end

        def serialize(r, detail:, include_internal: false)
          # ... reuse serialize from AnalysisRequestsController + internal notes if include_internal
        end

        def notify_acceptance(r)
          Notifications::WorkflowEvents.analysis_request_accepted(r)
          AnalysisRequestsMailer.accepted(r).deliver_later
        end

        def notify_rejection(r)
          Notifications::WorkflowEvents.analysis_request_rejected(r)
          AnalysisRequestsMailer.rejected(r).deliver_later
        end

        def notify_quote(r)
          Notifications::WorkflowEvents.analysis_request_quoted(r)
          AnalysisRequestsMailer.quoted(r).deliver_later
        end

        def notify_coach_assignment(r)
          Notifications::WorkflowEvents.analysis_request_coach_assigned(r)
          AnalysisRequestsMailer.coach_assigned(r).deliver_later
        end
      end
    end
  end
end
```
---

## Member Actions on Main Controller (for coach/submitter where permitted)

```ruby
# app/controllers/api/v1/analysis_requests_controller.rb (add member routes)
member do
  post :accept      # admin/curator only (policy)
  post :reject      # admin/curator only
  post :quote       # admin/curator only
  post :assign_coach # admin/curator only
  post :mark_invoice_sent
  post :mark_paid
  post :start_work
  post :complete
  post :cancel
end
```

---

## Routes

```ruby
# config/routes.rb
namespace :admin do
  resources :analysis_requests, only: [:index, :show] do
    member do
      post :accept
      post :reject
      post :quote
      post :assign_coach
      post :internal_notes, action: :add_internal_note
    end
  end
end

# On main resources :analysis_requests
member do
  post :accept
  post :reject
  post :quote
  post :assign_coach
  post :mark_invoice_sent
  post :mark_paid
  post :start_work
  post :complete
  post :cancel
end
```

---

## Notifications & Email Events

Add to `Notifications::WorkflowEvents`:
- `analysis_request_accepted(request)` — to submitter + crew
- `analysis_request_rejected(request)` — to submitter
- `analysis_request_quoted(request)` — to submitter
- `analysis_request_coach_assigned(request)` — to coach + crew

New mailer: `AnalysisRequestsMailer` with `accepted`, `rejected`, `quoted`, `coach_assigned` methods.

---

## Test Plan

- Admin index: filters (status, payment_status, coach, search), pagination
- Admin show: includes internal notes
- Accept: sets price, workflow_status=accepted, sends notification+email
- Reject: requires reason, workflow_status=rejected, sends notification+email
- Quote: sets price, workflow_status=quoted, sends notification+email
- Assign coach: validates coach exists + connected to account, sends notification+email
- Policy: only admin/curator can access admin namespace actions
- Coach can start_work/complete on assigned requests

---

## Delivered Surfaces (frontend, IDENTITY-265 follow-up)

| Surface | Route | Notes |
|---------|-------|-------|
| Staff triage inbox | `/admin/analysis-requests` (`AdminAnalysisRequestsPage`) | Reference search + workflow/payment filters; `PlatformStaffRoute` guard; consumes `GET /api/v1/admin/analysis_requests` |
| Shared request detail | `/analysis-requests/:id` (`AnalysisRequestDetailPage`) | Submitter, coach and staff view. Staff-only panel drives accept / reject / quote / assign coach / invoice sent / paid / start / complete / cancel plus internal notes |
| Sidebar | `Analysis Requests → Manage Requests` group | Visible to curator + admin only (`platformStaffOnly`) |

Workflow actions were added to **`Api::V1::AnalysisRequestsController`** (the routes already existed but had no actions), so the SPA has one code path for staff and coach transitions. `AnalysisRequestPolicy#cancel?` was added for the cancel transition. Internal notes are exposed on the shared detail serializer only to admin/curator (`staff_viewer?`), and the admin serializer now also carries `guest_name` / `guest_email` / `submitter_email`.

## Acceptance Criteria

- [x] Admin list/detail API works with filters & pagination
- [x] Accept/Reject/Quote/Assign coach actions work (main + admin controllers)
- [x] In-app notifications emitted on each transition (email remains submission-only — see deviation)
- [x] Policy enforcement: submitter cannot accept/reject; coach cannot assign
- [x] Internal notes only visible to admin/curator
- [x] `bin/rails test` passes (`api/v1/admin/analysis_requests_controller_test.rb` covers forbidden/index/search/internal notes)

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Admin UI server-rendered | JSON API + React pages (consistent with repo) | `namespace :admin` in routes already JSON |
| Custom quote UI | Single `quote` action with price_cents | Simpler, matches manual invoicing |
| **Tests** | `test/controllers/api/v1/admin/analysis_requests_controller_test.rb` | Was missing; added with the UI |
| Transition emails | In-app notifications only; `AnalysisRequestsMailer` still sends only submission + guest confirmation | Avoids surprising the submitter mid-triage; revisit if product wants status emails |
| Separate admin detail page | Staff reuse `/analysis-requests/:id` with a staff-only action panel | One serializer, one page, no duplicated rendering logic |