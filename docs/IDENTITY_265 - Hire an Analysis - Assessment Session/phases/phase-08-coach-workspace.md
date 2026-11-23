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

## Acceptance Criteria

- [ ] Coach sees only assigned requests
- [ ] Video playback with timestamped annotations works
- [ ] Coach can add text/drawing/telestration annotations
- [ ] Coach can upload deliverables (PDF, video)
- [ ] `start_work` / `complete` transitions work
- [ ] Notifications + emails on work_started, completed
- [ ] Mobile-friendly (responsive)
- [ ] `bin/rails test` + `npm run test` pass

---

## Deviations from Parent Plan

| Plan Item | Deviation | Reason |
|-----------|-----------|--------|
| Separate annotation model | `AnalysisRequestAnnotation` (not reusing `AnalysisAnnotation`) | Scoped to request videos; cleaner |
| Telestration | HTML5 canvas overlay | Lightweight, no external deps |