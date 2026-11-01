module Api
  module V1
    class SkillsController < ApplicationController
      before_action :set_skill, only: [:show, :update, :destroy]
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      def index
        # Public catalogue: only published, shared skills (policy scope).
        @skills = policy_scope(Skill).includes(:category)
        render json: @skills, include: :category
      end

      def show
        authorize @skill
        render json: @skill, include: {
          category: { only: [ :id, :name, :slug ] },
          video_references: {
            only: VideoReferencesController::REFERENCE_ONLY,
            methods: VideoReferencesController::REFERENCE_METHODS,
            include: { video: { only: VideoReferencesController::VIDEO_ONLY, methods: VideoReferencesController::VIDEO_METHODS } }
          }
        }
      end

      def create
        authorize Skill, :create?
        @skill = Skill.new(skill_params.merge(created_by: Current.user))

        if @skill.save
          render json: @skill, status: :created
        else
          render json: { errors: @skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @skill
        if @skill.update(skill_params)
          render json: @skill
        else
          render json: { errors: @skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @skill
        @skill.destroy
        head :no_content
      end

      private

      def set_skill
        @skill = Skill.includes({ video_references: :video }, :category)
                      .find_by(slug: params[:id]) ||
                 Skill.includes({ video_references: :video }, :category)
                      .find_by(id: params[:id])
        render json: { error: "Skill not found" }, status: :not_found if @skill.nil?
      end

      def skill_params
        params.require(:skill).permit(:title, :category_id, :description)
      end
    end
  end
end