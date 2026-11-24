module Api
  module V1
    module Admin
      class AnalysisRequestsController < ApplicationController
        # Api::V1::ApplicationController skips authentication by default; the
        # admin namespace always requires a signed-in staff member.
        before_action :require_authentication
        before_action :authorize_admin!
        before_action :set_request, only: [:show, :accept, :reject, :quote, :assign_coach, :add_internal_note]

        def index
          requests = policy_scope(AnalysisRequest).ordered
          requests = requests.where(workflow_status: params[:status]) if params[:status].present?
          requests = requests.where(payment_status: params[:payment_status]) if params[:payment_status].present?
          requests = requests.where(assigned_coach_profile_id: params[:coach_id]) if params[:coach_id].present?
          requests = requests.where("reference ILIKE ?", "%#{params[:q]}%") if params[:q].present?
          page = (params[:page] || 1).to_i
          per = (params[:per] || 20).to_i.clamp(1, 100)
          total_count = requests.count
          requests = requests.offset((page - 1) * per).limit(per)
          render json: {
            data: requests.map { |r| serialize(r, detail: true) },
            meta: {
              current_page: page,
              per_page: per,
              total_pages: (total_count / per.to_f).ceil,
              total_count: total_count
            }
          }
        end

        def show
          render json: { analysis_request: serialize(@request, detail: true, include_internal: true) }
        end

        def accept
          price_cents = params[:price_cents]&.to_i || @request.package&.price_cents || 0
          @request.accept!(price_cents: price_cents)
          notify_acceptance(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        def reject
          reason = params[:reason]
          return render json: { errors: ["Rejection reason required"] }, status: :unprocessable_entity if reason.blank?
          @request.reject!(reason)
          notify_rejection(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        def quote
          price_cents = params[:price_cents]&.to_i
          return render json: { errors: ["Price required"] }, status: :unprocessable_entity unless price_cents&.>= 0
          @request.quote!(price_cents)
          notify_quote(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        def assign_coach
          coach = CoachProfile.find(params[:coach_profile_id])
          @request.update!(assigned_coach_profile: coach)
          notify_coach_assignment(@request)
          render json: { analysis_request: serialize(@request.reload, detail: true) }
        end

        def add_internal_note
          note = @request.analysis_request_internal_notes.create!(body: params[:body], account: current_user.account)
          render json: { internal_note: serialize_internal_note(note) }
        end

        private

        def authorize_admin!
          head :forbidden unless current_user.admin? || current_user.curator?
        end

        def set_request
          @request = AnalysisRequest.find(params[:id])
        end

        def serialize(request, detail:, include_internal: false)
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
            if include_internal
              data[:internal_notes] = request.analysis_request_internal_notes.map { |n| serialize_internal_note(n) }
            end
          end
          data[:account_id] = request.account_id
          # Staff triage needs the submitter's contact details.
          data[:guest_name] = request.guest_name
          data[:guest_email] = request.guest_email
          data[:submitter_email] = request.account&.email.presence || request.guest_email
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
          { id: s.id, title: s.name, status: s.status, date: s.scheduled_on&.iso8601 }
        end

        def serialize_internal_note(n)
          { id: n.id, body: n.body, created_at: n.created_at.iso8601, author: n.account ? { id: n.account.id, name: n.account.full_name } : nil }
        end

        def format_price(cents)
          return "Complimentary" if cents == 0
          "$#{'%.2f' % (cents / 100.0)} AUD"
        end

        def notify_acceptance(request)
          Notifications::WorkflowEvents.analysis_request_accepted(request) if defined?(Notifications::WorkflowEvents)
          AnalysisRequestsMailer.accepted(request).deliver_later if defined?(AnalysisRequestsMailer)
        end

        def notify_rejection(request)
          Notifications::WorkflowEvents.analysis_request_rejected(request) if defined?(Notifications::WorkflowEvents)
          AnalysisRequestsMailer.rejected(request).deliver_later if defined?(AnalysisRequestsMailer)
        end

        def notify_quote(request)
          Notifications::WorkflowEvents.analysis_request_quoted(request) if defined?(Notifications::WorkflowEvents)
          AnalysisRequestsMailer.quoted(request).deliver_later if defined?(AnalysisRequestsMailer)
        end

        def notify_coach_assignment(request)
          Notifications::WorkflowEvents.analysis_request_coach_assigned(request) if defined?(Notifications::WorkflowEvents)
          AnalysisRequestsMailer.coach_assigned(request).deliver_later if defined?(AnalysisRequestsMailer)
        end
      end
    end
  end
end
