module Api
  module V1
    class DrillsController < ApplicationController
      before_action :set_drill, only: [ :show, :update, :destroy ]
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      def index
        # Public endpoint: the policy scope returns only published, shared
        # drills. Draft, private, unlisted, archived, or rejected drills are
        # never listed.
        @drills = policy_scope(Drill).includes(skills: :category).order(:title)
        # `except` drops the heavy definition blob; `has_definition` tells the
        # client whether a visualisation exists without transferring it.
        render json: @drills, except: [ :definition ], methods: [ :has_definition ], include: {
          skills: { only: [ :id, :title, :slug ], include: { category: { only: [ :id, :name, :slug ] } } }
        }
      end

      def show
        authorize @drill
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
        authorize Drill, :create?
        # Status is set server-side on create and a client-supplied value is
        # ignored: a coach must never be able to publish a drill directly,
        # bypassing the review/approval step. Content managers (coach/curator/
        # admin) start at `submitted`; anything else (defence in depth — the
        # policy already restricts creation) starts at `draft`.
        @drill = Drill.new(drill_params.except(:status).merge(created_by: Current.user))
        @drill.status = Current.user&.content_manager? ? :submitted : :draft

        if @drill.save
          render json: @drill, status: :created
        else
          render json: { errors: @drill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @drill
        # Visibility is an ownership decision; status is a content-manager one.
        authorize @drill, :change_visibility? if drill_params.key?(:visibility)
        authorize @drill, :change_status? if drill_params.key?(:status)

        if @drill.update(drill_params)
          render json: @drill
        else
          render json: { errors: @drill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @drill
        @drill.destroy
        head :no_content
      end

      private

      def set_drill
        @drill = Drill.includes(:training_sessions, { video_references: :video }, skills: :category)
                      .find_by(slug: params[:id]) ||
                Drill.includes(:training_sessions, { video_references: :video }, skills: :category)
                     .find_by(id: params[:id])
        render_not_found_api if @drill.nil?
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
