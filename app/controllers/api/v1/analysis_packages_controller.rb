module Api
  module V1
    class AnalysisPackagesController < ApplicationController
      allow_unauthenticated_access only: %i[index show]
      before_action :require_authentication, only: %i[admin_index create update destroy]
      before_action :require_admin, only: %i[admin_index create update destroy]
      before_action :set_package, only: %i[show update destroy]

      def index
        packages = AnalysisPackage.active
        render json: { data: packages.map { |p| serialize(p) } }
      end

      # Admin-only: returns all packages including inactive
      def admin_index
        packages = AnalysisPackage.ordered
        render json: { data: packages.map { |p| serialize(p) } }
      end

      def show
        render json: { package: serialize_detail(@package) }
      end

      def create
        @package = AnalysisPackage.new(package_params)
        if @package.save
          render json: { package: serialize_detail(@package) }, status: :created
        else
          render json: { errors: @package.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @package.update(package_params)
          render json: { package: serialize_detail(@package) }
        else
          render json: { errors: @package.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @package.destroy!
        head :no_content
      end

      private

      def set_package
        @package = AnalysisPackage.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Analysis package not found" }, status: :not_found
      end

      def require_admin
        return if Current.user&.admin?

        render json: { error: "Admins only" }, status: :forbidden
      end

      def package_params
        params.require(:analysis_package).permit(
          :key, :name, :description, :price_cents, :max_videos,
          :max_duration_minutes, :includes_annotated_video, :includes_written_report,
          :includes_consultation, :turnaround_days, :position, :active
        )
      end

      def serialize(p)
        {
          id: p.id,
          key: p.key,
          name: p.name,
          description: p.description,
          price_cents: p.price_cents,
          price_aud: p.price_aud,
          max_videos: p.max_videos,
          max_duration_minutes: p.max_duration_minutes,
          includes_annotated_video: p.includes_annotated_video,
          includes_written_report: p.includes_written_report,
          includes_consultation: p.includes_consultation,
          turnaround_days: p.turnaround_days,
          active: p.active,
          position: p.position
        }
      end

      def serialize_detail(p)
        serialize(p).merge(
          created_at: p.created_at,
          updated_at: p.updated_at
        )
      end
    end
  end
end