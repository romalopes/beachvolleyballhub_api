module Api
  module V1
    class AnalysisAnnotationsController < ApplicationController
      before_action :require_authentication
      before_action :set_video
      before_action :authorize_manage!
      before_action :set_annotation, only: %i[update destroy]

      def create
        annotation = @video.analysis_annotations.new(annotation_params.merge(author: Current.user))

        if annotation.save
          render json: { id: annotation.id }, status: :created
        else
          render json: { errors: annotation.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @annotation.update(annotation_params)
          render json: { id: @annotation.id }
        else
          render json: { errors: @annotation.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @annotation.destroy!
        head :no_content
      end

      private

      def set_video
        @video = AnalysisVideo.includes(:analysis).find(params[:analysis_video_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Analysis video not found" }, status: :not_found
      end

      def authorize_manage!
        render_unauthorized_or_forbidden unless AnalysisPolicy.new(actor: Current.user, analysis: @video.analysis).manage?
      end

      def set_annotation
        @annotation = @video.analysis_annotations.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Annotation not found" }, status: :not_found
      end

      def annotation_params
        params.require(:annotation).permit(:timestamp_seconds, :body, :player_profile_id)
      end
    end
  end
end