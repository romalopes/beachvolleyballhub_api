module Api
  module V1
    # Conversation between the submitter and the team (IDENTITY-265).
    #
    # Every visitor of the request can read it (owner, assigned coach, staff);
    # only staff see internal messages. Guests reach the same conversation
    # through their token instead of a session, and can only ever post as the
    # submitter — never internal.
    #
    # Notifications and the per-message email are emitted by the model, so any
    # creation path (session or token) behaves identically.
    class AnalysisRequestMessagesController < ApplicationController
      before_action :require_authentication, except: [ :guest_create ]
      before_action :set_analysis_request, only: %i[index create]

      # GET /api/v1/analysis_requests/:analysis_request_id/messages
      def index
        authorize @analysis_request, :show?

        messages = @analysis_request.analysis_request_messages.order(:created_at)
        messages = messages.where(internal: false) unless staff?

        render json: { data: messages.map { |message| serialize(message) } }
      end

      # POST /api/v1/analysis_requests/:analysis_request_id/messages
      def create
        authorize @analysis_request, :add_message?

        body = params[:body].to_s.strip
        if body.blank?
          return render json: { errors: [ "A message body is required" ] },
                        status: :unprocessable_entity
        end

        internal = staff? && ActiveModel::Type::Boolean.new.cast(params[:internal]).present?

        message = @analysis_request.analysis_request_messages.new(
          body: body,
          internal: internal,
          from_submitter: submitter?,
          account: current_user.account,
          user: current_user
        )

        save(message)
      end

      # POST /api/v1/analysis_requests/guest_access/:token/messages
      def guest_create
        request = AnalysisRequest.find_by_guest_access!(params[:token])
        body = params[:body].to_s.strip
        if body.blank?
          return render json: { errors: [ "A message body is required" ] },
                        status: :unprocessable_entity
        end

        message = request.analysis_request_messages.new(
          body: body, internal: false, from_submitter: true
        )

        save(message)
      end

      private

      def set_analysis_request
        @analysis_request = AnalysisRequest.find(params[:analysis_request_id])
      end

      def save(message)
        if message.save
          render json: { message: serialize(message) }, status: :created
        else
          render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def submitter?
        current_user.account.present? && @analysis_request.account_id == current_user.account.id
      end

      def staff?
        current_user.admin? || current_user.curator?
      end

      def serialize(message)
        {
          id: message.id,
          body: message.body,
          from_submitter: message.from_submitter,
          internal: message.internal,
          created_at: message.created_at.iso8601,
          author: message.account ? { id: message.account.id, name: message.account.full_name } : nil
        }
      end
    end
  end
end
