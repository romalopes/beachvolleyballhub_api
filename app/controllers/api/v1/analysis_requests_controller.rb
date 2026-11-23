module Api
  module V1
    class AnalysisRequestsController < ApplicationController
      # This controller inherits Api::V1::ApplicationController, which skips the
      # global authentication callback; re-enable it for the private actions and
      # opt the public ones out explicitly.
      before_action :require_authentication, except: [:create, :guest_access]
      # `guest_access` resolves its own record from the token, so it must not go
      # through the id lookup (there is no :id in that route).
      WORKFLOW_ACTIONS = %i[
        accept reject quote assign_coach mark_invoice_sent mark_paid
        start_work complete cancel add_internal_note email_invoice start_analysis
      ].freeze

      before_action :set_analysis_request,
                    only: [ :show, :update, :destroy, *WORKFLOW_ACTIONS ]
      before_action :authorize_analysis_request!, only: [:show, :update, :destroy]

      allow_unauthenticated_access only: [:create]
      def create
        @analysis_request = build_analysis_request
        authorize @analysis_request, :create?

        if @analysis_request.save
          notify_submission(@analysis_request)
          render json: { analysis_request: serialize(@analysis_request, detail: true) }, status: :created
        else
          render json: { errors: @analysis_request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def index
        requests = policy_scope(AnalysisRequest).ordered

        requests = requests.where(workflow_status: params[:status]) if params[:status].present?
        requests = requests.where(payment_status: params[:payment_status]) if params[:payment_status].present?
        requests = requests.where(assigned_coach_profile_id: params[:coach_id]) if params[:coach_id].present?

        page = (params[:page] || 1).to_i
        per = (params[:per] || 20).to_i.clamp(1, 100)
        total_count = requests.count
        requests = requests.offset((page - 1) * per).limit(per)

        render json: {
          data: requests.map { |r| serialize(r, detail: false) },
          meta: {
            current_page: page,
            per_page: per,
            total_pages: (total_count / per.to_f).ceil,
            total_count: total_count
          }
        }
      end

      def show
        render json: { analysis_request: serialize(@analysis_request, detail: true) }
      end

      def update
        if @analysis_request.update(analysis_request_update_params)
          render json: { analysis_request: serialize(@analysis_request.reload, detail: true) }
        else
          render json: { errors: @analysis_request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @analysis_request.destroy
        head :no_content
      end

      allow_unauthenticated_access only: [:guest_access]
      def guest_access
        @analysis_request = AnalysisRequest.find_by_guest_access!(params[:token])
        render json: { analysis_request: serialize(@analysis_request, detail: true, for_guest: true) }
      end

      def link_assessment_session
        session = AssessmentSession.find(params[:assessment_session_id])
        @analysis_request.assessment_sessions << session unless @analysis_request.assessment_sessions.include?(session)
        render json: { analysis_request: serialize(@analysis_request.reload, detail: true) }
      end

      def unlink_assessment_session
        @analysis_request.assessment_sessions.delete(params[:assessment_session_id])
        render json: { analysis_request: serialize(@analysis_request.reload, detail: true) }
      end

      def download_deliverable
        doc = @analysis_request.analysis_request_documents.find(params[:document_id])
        redirect_to rails_blob_url(doc.file, disposition: "attachment")
      end

      # --- workflow transitions (staff / assigned coach) ----------------------

      def accept
        authorize @analysis_request, :accept?
        price = params[:price_cents].present? ? params[:price_cents].to_i : @analysis_request.price_cents
        @analysis_request.accept!(price_cents: price)
        Notifications::WorkflowEvents.analysis_request_accepted(@analysis_request)
        render_workflow_result
      end

      def reject
        authorize @analysis_request, :reject?
        reason = params[:reason].to_s.strip
        if reason.blank?
          return render json: { errors: [ "A rejection reason is required" ] },
                        status: :unprocessable_entity
        end

        @analysis_request.reject!(reason)
        Notifications::WorkflowEvents.analysis_request_rejected(@analysis_request)
        render_workflow_result
      end

      def quote
        authorize @analysis_request, :quote?
        price = params[:price_cents].presence&.to_i
        if price.nil? || price.negative?
          return render json: { errors: [ "A quoted price is required" ] },
                        status: :unprocessable_entity
        end

        @analysis_request.quote!(price)
        Notifications::WorkflowEvents.analysis_request_quoted(@analysis_request)
        render_workflow_result
      end

      def assign_coach
        authorize @analysis_request, :assign_coach?
        coach = CoachProfile.find_by(id: params[:coach_profile_id])
        if coach.nil? || coach.account_id.blank?
          return render json: { errors: [ "Choose a coach with a connected account" ] },
                        status: :unprocessable_entity
        end

        @analysis_request.update!(assigned_coach_profile: coach)
        Notifications::WorkflowEvents.analysis_request_coach_assigned(@analysis_request)
        render_workflow_result
      end

      def mark_invoice_sent
        authorize @analysis_request, :mark_invoice_sent?
        @analysis_request.mark_invoice_sent!(external_reference: params[:external_reference].presence)
        Notifications::WorkflowEvents.analysis_request_invoice_sent(@analysis_request)
        render_workflow_result
      end

      def mark_paid
        authorize @analysis_request, :mark_paid?
        @analysis_request.mark_paid!
        Notifications::WorkflowEvents.analysis_request_payment_received(@analysis_request)
        render_workflow_result
      end

      def start_work
        authorize @analysis_request, :start_work?
        @analysis_request.start_work!
        Notifications::WorkflowEvents.analysis_request_work_started(@analysis_request)
        render_workflow_result
      end

      def complete
        authorize @analysis_request, :complete?
        publish_linked_analysis!
        @analysis_request.complete!
        Notifications::WorkflowEvents.analysis_request_completed(@analysis_request)
        render_workflow_result
      end

      # Creates the linked Analysis and starts production (IDENTITY-265).
      # Idempotent: once linked, the existing analysis is returned with 200.
      def start_analysis
        authorize @analysis_request, :start_work?

        if @analysis_request.analysis.present?
          return render json: { analysis_request: serialize(@analysis_request, detail: true) }
        end

        AnalysisRequests::AnalysisStarter.new(
          request: @analysis_request, actor: current_user
        ).call

        render json: { analysis_request: serialize(@analysis_request.reload, detail: true) },
               status: :created
      rescue AnalysisRequests::AnalysisStarter::NotApproved => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      def cancel
        authorize @analysis_request, :cancel?
        @analysis_request.cancel!
        render_workflow_result
      end

      # Emails the latest invoice (creating one when none exists) with a PDF
      # attachment. Returns 202 because delivery happens in the job.
      def email_invoice
        authorize @analysis_request, :mark_invoice_sent?

        if @analysis_request.price_cents.to_i <= 0
          return render json: { errors: [ "Set a price before emailing an invoice" ] },
                        status: :unprocessable_entity
        end

        invoice = @analysis_request.analysis_request_invoices.order(created_at: :desc).first ||
                  @analysis_request.analysis_request_invoices.create!(
                    amount_cents: @analysis_request.price_cents,
                    currency: "AUD",
                    status: "pending"
                  )

        AnalysisRequestInvoiceEmailJob.perform_later(invoice.id)

        render json: { queued: true, invoice: serialize_invoice(invoice) }, status: :accepted
      end

      def add_internal_note
        authorize @analysis_request, :add_internal_note?
        body = params[:body].to_s.strip
        if body.blank?
          return render json: { errors: [ "A note body is required" ] },
                        status: :unprocessable_entity
        end

        note = @analysis_request.analysis_request_internal_notes.create!(
          body: body, account: current_user.account
        )
        render json: {
          internal_note: {
            id: note.id,
            body: note.body,
            created_at: note.created_at.iso8601,
            author: { id: note.account.id, name: note.account.full_name }
          }
        }, status: :created
      end

      private

      def render_workflow_result
        render json: { analysis_request: serialize(@analysis_request.reload, detail: true) }
      end

      # Completing the request is the delivery point: the linked analysis must be
      # shared at the same moment, otherwise the submitter would be told the work
      # is done while the analysis stays invisible.
      def publish_linked_analysis!
        analysis = @analysis_request.analysis
        return if analysis.nil? || analysis.published? || analysis.archived?

        analysis.publish!
      end

      def set_analysis_request
        @analysis_request = AnalysisRequest.find(params[:id])
      end

      def authorize_analysis_request!
        authorize @analysis_request
      end

      def build_analysis_request
        attrs = analysis_request_create_params
        if current_user
          attrs[:account] = current_user.account
          attrs[:guest_name] = nil
          attrs[:guest_email] = nil
          # The submitter's player identity: reused when the account already
          # has one, created on the fly otherwise (IDENTITY-265). A failure to
          # resolve must never block the request itself, so fall back to nil.
          attrs[:player_profile] = AnalysisRequests::SubmitterProfile.for_user(current_user).profile
        end

        # The package price is server-authoritative; an unknown or inactive key
        # is rejected by AnalysisRequest#package_is_available.
        if attrs[:package_key].present?
          package = AnalysisPackage.active.find_by(key: attrs[:package_key])
          attrs[:price_cents] = package.price_cents if package
        end

        if attrs[:analysis_request_videos_attributes].present?
          attrs[:analysis_request_videos_attributes] =
            normalize_video_attributes(attrs[:analysis_request_videos_attributes])
        end

        AnalysisRequest.new(attrs)
      end

      # Older clients posted the provider URL in `video_id`. That column is an
      # integer FK, so move URL-shaped values to `external_url` instead of
      # rejecting (or, worse, casting them to 0).
      def normalize_video_attributes(videos)
        return videos if videos.blank?

        entries = videos.respond_to?(:to_h) ? videos.to_h.values : Array(videos)

        entries.map do |entry|
          attributes = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : entry
          next attributes unless attributes.is_a?(Hash)

          if attributes[:source_type].to_s == "external" &&
             attributes[:external_url].blank? &&
             attributes[:video_id].to_s.match?(%r{\Ahttps?://}i)
            attributes[:external_url] = attributes.delete(:video_id)
          end

          attributes
        end
      end

      def analysis_request_create_params
        params.require(:analysis_request).permit(
          :title, :description, :package_key,
          :guest_name, :guest_email,
          analysis_request_videos_attributes: [:source_type, :video_id, :external_url, :file, :position]
        )
      end

      def analysis_request_update_params
        params.require(:analysis_request).permit(:title, :description)
      end

      def serialize(request, detail:, for_guest: false)
        data = {
          id: request.id,
          reference: request.reference,
          title: request.title,
          description: request.description,
          package_key: request.package_key,
          price_cents: request.price_cents,
          price_aud: format_price(request.price_cents),
          workflow_status: request.workflow_status,
          payment_status: request.payment_status,
          submitted_at: request.submitted_at&.iso8601,
          accepted_at: request.accepted_at&.iso8601,
          completed_at: request.completed_at&.iso8601,
          assigned_coach: request.assigned_coach_profile ? {
            id: request.assigned_coach_profile.id,
            display_name: request.assigned_coach_profile.display_name
          } : nil
        }

        if detail
          data[:videos] = request.analysis_request_videos.map { |v| serialize_video(v) }
          # Guests see the conversation but never internal staff notes.
          visible_messages = if for_guest
                               request.analysis_request_messages.visible_to_submitter.to_a
                             else
                               request.analysis_request_messages.order(:created_at).to_a
                             end
          data[:messages] = visible_messages.map { |m| serialize_message(m) }
          data[:deliverables] = request.analysis_request_documents.map { |d| serialize_deliverable(d) }
          data[:assessment_sessions] = request.assessment_sessions.map { |s| serialize_assessment_session(s) }
        end

        if for_guest
          data[:guest_name] = request.guest_name
          data[:guest_email] = request.guest_email
        else
          data[:account_id] = request.account_id
          # The submitter needs their secure link; staff can see it too so they
          # can resend it. Guests are never listed through this endpoint.
          data[:guest_access_token] = request.guest_access_token if request.guest?
        end

        # Staff triage needs the submitter's contact details and the internal
        # notes; submitters and coaches never receive them.
        if detail && staff_viewer?
          data[:guest_name] = request.guest_name
          data[:guest_email] = request.guest_email
          data[:submitter_email] = request.account&.email.presence || request.guest_email
          data[:internal_notes] = request.analysis_request_internal_notes.map do |note|
            {
              id: note.id,
              body: note.body,
              created_at: note.created_at.iso8601,
              author: { id: note.account_id, name: note.account.full_name }
            }
          end
          data[:invoices] = request.analysis_request_invoices
                                    .order(created_at: :desc)
                                    .map { |invoice| serialize_invoice(invoice) }
        end

        # Progress (and, once shared, the content) of the linked Analysis. Sent
        # to every viewer of the request — submitter, guest, coach and staff.
        if detail
          data[:analysis] = AnalysisRequests::AnalysisPresenter.new(
            request, blob_url: method(:rails_blob_url)
          ).as_json
        end

        data
      end

      def serialize_invoice(invoice)
        {
          id: invoice.id,
          number: invoice.number,
          amount_cents: invoice.amount_cents,
          amount_aud: invoice.amount_aud,
          currency: invoice.currency,
          status: invoice.status,
          external_reference: invoice.external_reference,
          sent_at: invoice.sent_at&.iso8601,
          paid_at: invoice.paid_at&.iso8601,
          emailed_at: invoice.emailed_at&.iso8601,
          created_at: invoice.created_at.iso8601
        }
      end

      def staff_viewer?
        current_user.present? && (current_user.admin? || current_user.curator?)
      end

      def serialize_video(v)
        {
          id: v.id,
          source_type: v.source_type,
          external_url: v.external_url,
          video_id: v.video_id,
          position: v.position,
          video: v.video ? { id: v.video.id, title: v.video.title, provider: v.video.provider_label, duration: v.video.duration_seconds, embed_url: v.video.embed_url } : nil,
          file_url: v.file.attached? ? rails_blob_url(v.file) : nil,
          annotations_count: v.analysis_request_annotations.count
        }
      end

      def serialize_message(m)
        {
          id: m.id,
          body: m.body,
          from_submitter: m.from_submitter,
          internal: m.internal,
          created_at: m.created_at.iso8601,
          author: m.account ? { id: m.account.id, name: m.account.full_name } : nil
        }
      end

      def serialize_deliverable(d)
        {
          id: d.id,
          title: d.title,
          file_url: d.file.attached? ? rails_blob_url(d.file) : nil,
          created_at: d.created_at.iso8601
        }
      end

      def serialize_assessment_session(s)
        { id: s.id, title: s.title, status: s.status, date: s.session_date&.iso8601 }
      end

      def format_price(cents)
        return "Complimentary" if cents == 0
        "$#{'%.2f' % (cents / 100.0)} AUD"
      end

      def notify_submission(request)
        # In-app bell for the crew...
        Notifications::WorkflowEvents.analysis_request_submitted(request) if defined?(Notifications::WorkflowEvents)
        # ...and the two transactional emails (crew + submitter), delivered off
        # the request so a slow mail provider cannot delay the response.
        AnalysisRequestSubmissionJob.perform_later(request)
      end
    end
  end
end