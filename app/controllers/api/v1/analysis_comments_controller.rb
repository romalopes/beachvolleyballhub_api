module Api
  module V1
    class AnalysisCommentsController < ApplicationController
      before_action :require_authentication
      before_action :set_analysis
      before_action :authorize_comment!, only: :create
      before_action :set_comment, only: :destroy

      def create
        comment = @analysis.analysis_comments.new(comment_params.merge(author: Current.user))

        if comment.save
          render json: { id: comment.id }, status: :created
        else
          render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        unless Current.user&.admin? || @comment.author_id == Current.user&.id
          return render_unauthorized_or_forbidden
        end

        @comment.destroy!
        head :no_content
      end

      private

      def set_analysis
        @analysis = Analysis.find(params[:analysis_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Analysis not found" }, status: :not_found
      end

      def authorize_comment!
        render_unauthorized_or_forbidden unless AnalysisPolicy.new(actor: Current.user, analysis: @analysis).comment?
      end

      def set_comment
        @comment = @analysis.analysis_comments.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Comment not found" }, status: :not_found
      end

      def comment_params
        params.require(:comment).permit(:body, :parent_id)
      end
    end
  end
end