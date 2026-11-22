module Api
  module V1
    # Drill↔Skill links. The JSON API is public by default and the SPA's API
    # health check reads `GET /api/v1/drill_skills`, so index/show stay readable
    # anonymously (they expose only public catalogue relationships). Writes,
    # however, mutate the catalogue and MUST be authenticated and authorized —
    # see SEC-01 in docs/security-audit/audity-security-report.md.
    class DrillSkillsController < ApplicationController
      include ContentAuthorization

      before_action :set_drill_skill, only: [ :show, :update, :destroy ]
      before_action :require_authentication, only: %i[create update destroy]
      before_action :require_content_creator!, only: %i[create update destroy]
      before_action :authorize_drill_manage!, only: %i[update destroy]

      def index
        @drill_skills = DrillSkill.includes(:drill, :skill).all
        render json: @drill_skills, include: [ :drill, :skill ]
      end

      def show
        render json: @drill_skill, include: [ :drill, :skill ]
      end

      def create
        drill = Drill.find_by(id: drill_skill_params[:drill_id])
        return render json: { error: "Drill not found" }, status: :not_found if drill.nil?

        # Linking a skill to a drill edits that drill (owner or admin only).
        authorize drill, :update?

        @drill_skill = DrillSkill.new(drill_skill_params)

        if @drill_skill.save
          render json: @drill_skill, status: :created
        else
          render json: { errors: @drill_skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @drill_skill.update(drill_skill_params)
          render json: @drill_skill
        else
          render json: { errors: @drill_skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @drill_skill.destroy
        head :no_content
      end

      private

      def set_drill_skill
        @drill_skill = DrillSkill.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "DrillSkill not found" }, status: :not_found
      end

      # Updating or deleting a link edits the underlying drill (owner or admin only).
      def authorize_drill_manage!
        return if @drill_skill.nil?

        authorize @drill_skill.drill, :update?
      end

      def drill_skill_params
        params.require(:drill_skill).permit(:drill_id, :skill_id)
      end
    end
  end
end
