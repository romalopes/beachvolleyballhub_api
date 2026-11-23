module Api
  module V1
    module Coach
      class AnalysisRequestsController < ApplicationController
        # Api::V1::ApplicationController skips authentication by default; the
        # coach workspace always requires a signed-in coach.
        before_action :require_authentication
        before_action :authorize_coach!
        before_action :set_request, only: [:show, :start_work, :complete, :add_annotation, :upload_deliverable]

        def index
          requests = AnalysisRequest.where(assigned_coach_profile_id: current_user.coach_profile_id).ordered
          requests = requests.where(workflow_status: params[:status]) if params[:status].present?
          page = (params[:page] || 1).to_i
          per = (params[:per] || 20).to_i.clamp(1, 100)
          total_count = requests.count
          requests = requests.offset((page - 1) * per).limit(per)
          render json: {
            data: requests.map { |r| serialize(r) },
            meta: {
              current_page: page,
              per_page: per,
              total_pages: (total_count / per.to_f).ceil,
              total_count: total_count
            }
          }
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
          annotation = video.analysis_request_annotations.create!(annotation_params.merge(author: current_user))
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

        def serialize(request, detail: false)
          data = { id: request.id, reference: request.reference, title: request.title, description: request.description,
            package_key: request.package_key, price_cents: request.price_cents, price_aud: format_price(request.price_cents),
            workflow_status: request.workflow_status, payment_status: request.payment_status,
            submitted_at: request.submitted_at&.iso8601, accepted_at: request.accepted_at&.iso8601,
            completed_at: request.completed_at&.iso8601,
            assigned_coach: request.assigned_coach_profile ? { id: request.assigned_coach_profile.id, display_name: request.assigned_coach_profile.display_name } : nil }
          if detail
            data[:videos] = request.analysis_request_videos.map { |v| serialize_video(v) }
            data[:messages] = request.analysis_request_messages.map { |m| serialize_message(m) }
            data[:deliverables] = request.analysis_request_documents.map { |d| serialize_deliverable(d) }
            data[:assessment_sessions] = request.assessment_sessions.map { |s| serialize_assessment_session(s) }
          end
          data[:account_id] = request.account_id
          data
        end

        def serialize_video(v)
          { id: v.id, source_type: v.source_type, external_url: v.external_url, video_id: v.video_id, position: v.position,
            video: v.video ? { id: v.video.id, title: v.video.title, provider: v.video.provider_label, duration: v.video.duration_seconds, embed_url: v.video.embed_url } : nil,
            file_url: v.file.attached? ? rails_blob_url(v.file) : nil, annotations_count: v.analysis_request_annotations.count }
        end

        def serialize_message(m)
          { id: m.id, body: m.body, from_submitter: m.from_submitter, internal: m.internal, created_at: m.created_at.iso8601,
            author: m.account ? { id: m.account.id, name: m.account.full_name } : nil }
        end

        def serialize_deliverable(d)
          { id: d.id, title: d.title, file_url: d.file.attached? ? rails_blob_url(d.file) : nil, created_at: d.created_at.iso8601 }
        end

        def serialize_assessment_session(s)
          { id: s.id, title: s.title, status: s.status, date: s.session_date&.iso8601 }
        end

        def serialize_annotation(a)
          { id: a.id, timestamp_seconds: a.timestamp_seconds, body: a.body, annotation_type: a.annotation_type, created_at: a.created_at.iso8601 }
        end

        def serialize_document(d)
          { id: d.id, title: d.title, file_url: d.file.attached? ? rails_blob_url(d.file) : nil, created_at: d.created_at.iso8601 }
        end

        def format_price(cents)
          return "Complimentary" if cents == 0
          "$#{'%.2f' % (cents / 100.0)} AUD"
        end

        def notify_work_started(request)
          Notifications::WorkflowEvents.analysis_request_work_started(request) if defined?(Notifications::WorkflowEvents)
        end

        def notify_completed(request)
          Notifications::WorkflowEvents.analysis_request_completed(request) if defined?(Notifications::WorkflowEvents)
        end
      end
    end
  end
end