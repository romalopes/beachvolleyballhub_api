# Phase 8 — Coach Workspace & Analysis Production

**Goal:** Coach-facing UI for assigned requests: video review, annotations, deliverable creation, completion.

**Prerequisites:** Phase 7 complete ✅

---

## Repo Touchpoints

| Layer | Files to Create / Modify |
|-------|--------------------------|
| **Controller** | `app/controllers/api/v1/coach/analysis_requests_controller.rb` |
| **Model** | `app/models/analysis_request_annotation.rb` (timestamped notes on videos) |
| **Model** | `app/models/analysis_request_document.rb` (deliverables: PDF, annotated video) |
| **Routes** | `namespace :coach { resources :analysis_requests }` |
| **Frontend** | Coach workspace pages: list, detail, video player with annotations, deliverable upload |
| **Tests** | Coach CRUD on assigned requests |

---

## Models

```ruby
# app/models/analysis_request_annotation.rb
class AnalysisRequestAnnotation < ApplicationRecord
  belongs_to :analysis_request_video, inverse_of: :analysis_request_annotations
  validates :timestamp_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :body, presence: true
  validates :annotation_type, inclusion: { in: %w[text drawing telestration] }
end

# app/models/analysis_request_document.rb
class AnalysisRequestDocument < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_documents
  belongs_to :uploaded_by, class_name: "Account", optional: true
  has_one_attached :file
  validates :title, presence: true
  validates :document_type, inclusion: { in: %w[report annotated_video raw_video other] }
end
```

Migrations: `create_analysis_request_annotations` (video_id, timestamp_seconds, body, annotation_type) + `create_analysis_request_documents` (request_id, uploaded_by_id, title, document_type, file attachment).

---

## Coach Controller

```ruby
# app/controllers/api/v1/coach/analysis_requests_controller.rb
module Api
  module V1
    module Coach
      class AnalysisRequestsController < ApplicationController
        before_action :authenticate_user!
        before_action :authorize_coach!
        before_action :set_request, only: [:show, :start_work, :complete, :add_annotation, :upload_deliverable]

        def index
          requests = AnalysisRequest.where(assigned_coach_profile_id: current_user.coach_profile_id).ordered
          # filters: status, unread_messages
          render json: { data: requests.map { |r| serialize(r) } }
        end

        def show
          render json: { analysis_request: serialize(@request, detail: true) }
        end

        def start_work
          @request.start_work!
          notify_work_started(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        def complete
          @request.complete!
          notify_completed(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        def add_annotation
          video = @request.analysis_request_videos.find(params[:video_id])
          annotation = video.analysis_request_annotations.create!(annotation_params.merge(account: current_user.account))
          render json: { annotation: serialize_annotation(annotation) }, status: :created
        end

        def upload_deliverable
          doc = @request.analysis_request_documents.create!(deliverable_params.merge(uploaded_by: current_user.account))
          render json: { document: serialize_document(doc) }, status: :created
        end

        private

        def authorize_coach!
          head :forbidden unless current_user.coach? && current_user.coach_profile.present?
        end

        def set_request
          @request = AnalysisRequest.find(params[:id])
          head :forbidden unless @request.assigned_coach_profile_id == current_user.coach_profile_id
        end

        def annotation_params
          params.require(:annotation).permit(:timestamp_seconds, :body, :annotation_type)
        end

        def deliverable_params
          params.require(:document).permit(:title, :document_type, :file)
        end
      end
    end
  end
end
```

---

## Routes

```ruby
# config/routes.rb
namespace :coach do
  resources :analysis_requests, only: [:index, :show] do
    member do
      post :start_work
      post :complete
      post :annotations, action: :add_annotation
      post :deliverables, action: :upload_deliverable
    end
  end
end
```

---

## Frontend (Coach Workspace)

- `/coach/analysis-requests` — list with filters (assigned, in_progress, completed, unread)
- `/coach/analysis-requests/:id` — detail with:
  - Video player (uses existing `Video` playback components)
  - Annotation timeline (timestamped markers)
  - Drawing/telestration canvas (HTML5 canvas overlay)
  - Deliverable upload (drag-drop, progress)
  - Complete button (enabled when deliverables uploaded)

---

## Delivered: linked Analysis production (IDENTITY-265 follow-up)

| Piece | File | Notes |
|-------|------|-------|
| Link | migration `AddAnalysisToAnalysisRequests` + `AnalysisRequest#analysis` | One request points at one `Analysis`; deleting the analysis only unlinks it. |
| Video provenance | migration `AddAnalysisRequestVideoToAnalysisVideos` + `AnalysisVideo#analysis_request_video` | Every copied video keeps the id of the request video it came from; the analysis editor shows “From request ANL-…” on the card and “Request ANL-…” in the hero, both linking back to `/analysis-requests/:id`. Exposed as `analysis_request_video_id` (video) and `analysis_request` (analysis). |
| Starter | `app/services/analysis_requests/analysis_starter.rb` | Staff/assigned coach start an approved request (`accepted`/`awaiting_payment`/`in_progress`): creates a draft `Analysis`, copies the request's catalogue videos, uploaded blobs (shared, not duplicated) and resolvable external URLs (via `Video.find_or_create_from_url!`), links it, moves the request to `in_progress`. Rejects unapproved requests and double-starts. |
| API | `POST /api/v1/analysis_requests/:id/start_analysis` | 201 with the refreshed request (including progress); 200 + existing analysis when already started; 422 “Approve the request…”. Authorised by `start_work?` (staff or assigned coach). |
| Processing | existing `/analyses/:id/edit` editor | Request detail links managers straight into the full analysis editor (videos, comments, assessments, annotations). |
| Submitter view | `AnalysisRequests::AnalysisPresenter` + `AnalysisProgress` component | Detail/guest payloads carry `analysis`: steps + percent always; summary, videos and coach comments only once the analysis is shared. |
| Delivery | `complete` action | Publishes the linked analysis in the same step, so “completed” always means the submitter can read it; guest page renders the same progress block. |

## Acceptance Criteria

- [x] Coach sees only assigned requests (API scope) — coach UI still shares the request detail page
- [ ] Video playback with timestamped annotations works (annotation models exist; no annotation UI yet)
- [ ] Coach can add text/drawing/telestration annotations (API-side models only)
- [ ] Coach can upload deliverables (PDF, video) (API exists; no upload UI yet)
- [x] `start_work` / `complete` transitions work
- [x] Starting production creates and links a real Analysis, editable in `/analyses/:id/edit`
- [x] Submitter (account and guest) sees progress, then the finished analysis
- [x] Notifications on work_started, completed
- [x] `bin/rails test` + `npm run test` pass for the feature files

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Separate annotation model | `AnalysisRequestAnnotation` (not reusing `AnalysisAnnotation`) | Scoped to request videos; cleaner |
| Telestration | HTML5 canvas overlay | Lightweight, no external deps |
| Analysis production | Reuses the platform `Analysis` domain instead of building a request-only editor | Team keeps comments/annotations/assessment tooling; the request only tracks progress |
| Video copy | Uploaded blobs are shared, external URLs resolve to catalogue `Video` rows; unresolvable links stay on the request | Avoids duplicating bytes and keeps the media catalogue consistent |