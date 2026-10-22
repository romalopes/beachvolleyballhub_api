module Api
  module V1
    class AnalysisVideosController < ApplicationController
      before_action :require_authentication
      before_action :set_analysis
      before_action :authorize_manage!
      before_action :set_video, only: :destroy

      def create
        record = if params[:file].present?
          @analysis.analysis_videos.new(source_type: "upload", title: params[:title], description: params[:description], position: params[:position], file: params[:file])
        else
          external = Video.find_or_create_from_url!(params[:source_url], title: params[:title], description: params[:description], created_by: Current.user)
          return render json: { errors: ["Source URL is not a valid video link"] }, status: :unprocessable_entity if external.nil?
          @analysis.analysis_videos.new(source_type: "external", video: external, title: params[:title], description: params[:description], position: params[:position])
        end

        if record.save
          render json: { analysis_video_id: record.id }, status: :created
        else
          render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @video.destroy!
        head :no_content
      end

      private

      def set_analysis
        @analysis = Analysis.find(params[:analysis_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Analysis not found" }, status: :not_found
      end

      def authorize_manage!
        render_unauthorized_or_forbidden unless AnalysisPolicy.new(actor: Current.user, analysis: @analysis).manage?
      end

      def set_video
        @video = @analysis.analysis_videos.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Analysis video not found" }, status: :not_found
      end
    end
  end
end