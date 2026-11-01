module Api
  module V1
    class DrillsController < ApplicationController
      include ContentAuthorization
      before_action :set_drill, only: [ :show, :update, :destroy ]
      before_action :require_content_creator!, only: :create

      def index
        # Public endpoint: only return published drills with shared visibility.
        # Draft, private, unlisted, archived, or rejected drills are never listed.
        @drills = Drill.published_and_shared.includes(skills: :category).order(:title)
        # `except` drops the heavy definition blob; `has_definition` tells the
        # client whether a visualisation exists without transferring it.
        render json: @drills, except: [ :definition ], methods: [ :has_definition ], include: {
          skills: { only: [ :id, :title, :slug ], include: { category: { only: [ :id, :name, :slug ] } } }
        }
      end

      def show
        # Public endpoint: return the drill only if it is published and shared,
        # or if the current authenticated user is the creator.
        return render_not_found_api unless @drill
        unless @drill.published_and_shared? || Current.user == @drill.created_by
          return render_not_found_api
        end

        render json: @drill, include: {
          skills: { only: [ :id, :title, :description, :slug ], include: { category: { only: [ :id, :name, :slug ] } } },
          video_references: {
            only: VideoReferencesController::REFERENCE_ONLY,
            methods: VideoReferencesController::REFERENCE_METHODS,
            include: { video: { only: VideoReferencesController::VIDEO_ONLY, methods: VideoReferencesController::VIDEO_METHODS } }
          },
          training_sessions: { only: [ :id, :title, :starts_at, :ends_at, :location, :status ] }
        }
      end

      def create
        # Status is set server-side on create and a client-supplied value is
        # ignored: a coach must never be able to publish a drill directly,
        # bypassing the review/approval step. Content managers (coach/curator/
        # admin) start at `submitted`; anything else (defence in depth — the
        # before_action already restricts creation) starts at `draft`.
        @drill = Drill.new(drill_params.except(:status).merge(created_by: Current.user))
        @drill.status = Current.user&.content_manager? ? :submitted : :draft

        if @drill.save
          render json: @drill, status: :created
        else
          render json: { errors: @drill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # Visibility and status changes are restricted: only the owner or an
        # admin may change visibility; only an admin/curator may publish/reject.
        if drill_params.key?(:visibility) && !Current.user&.admin? && Current.user != @drill.created_by
          return render json: { error: "Only the drill owner or an admin can change visibility" }, status: :forbidden
        end

        if drill_params.key?(:status) && !Current.user&.content_manager?
          return render json: { error: "Only a content manager can change drill status" }, status: :forbidden
        end

        if @drill.update(drill_params)
          render json: @drill
        else
          render json: { errors: @drill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @drill.destroy
        head :no_content
      end

      private

      def set_drill
        @drill = Drill.includes(:training_sessions, { video_references: :video }, skills: :category)
                      .find_by(slug: params[:id]) ||
                Drill.includes(:training_sessions, { video_references: :video }, skills: :category)
                     .find_by(id: params[:id])
        authorize_content_owner!(@drill.created_by) unless action_name == "show"
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Drill not found" }, status: :not_found
      end

      def drill_params
        params.require(:drill).permit(
          :title, :setup_instructions, :training_stage, :difficulty_level,
          :min_players, :max_players, :ideal_num_players,
          :visibility, :status,
          # definition is a JSONB column validated against the v1 schema by the
          # model; permit it as an open hash since its structure is enforced
          # downstream. (A bare :definition symbol would drop the value.)
          definition: {}
        )
      end

      def render_not_found_api
        render json: { error: "Drill not found" }, status: :not_found
      end
    end
  end
end
