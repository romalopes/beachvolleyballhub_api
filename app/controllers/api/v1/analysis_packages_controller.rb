module Api
  module V1
    class AnalysisPackagesController < ApplicationController
      allow_unauthenticated_access

      def index
        packages = AnalysisPackage.active
        render json: { data: packages.map { |p| serialize(p) } }
      end

      private

      def serialize(p)
        {
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
          turnaround_days: p.turnaround_days
        }
      end
    end
  end
end