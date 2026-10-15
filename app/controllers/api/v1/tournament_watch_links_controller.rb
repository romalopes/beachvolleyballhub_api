module Api
  module V1
    # Ordered watch-link management for tournament admins (Phase 4):
    #   POST   /api/v1/tournaments/:tournament_id/watch_links
    #   PATCH  /api/v1/tournaments/:tournament_id/watch_links/:id
    #   DELETE /api/v1/tournaments/:tournament_id/watch_links/:id
    #
    # Position defaults to the next slot so links append in creation order and
    # reordering is an explicit PATCH of `position`.
    class TournamentWatchLinksController < ApplicationController
      include TournamentPayloads
      include TournamentManagementAuthorization

      before_action :set_tournament
      before_action :require_authentication

      def create
        return unless authorize_tournament_management!

        link = @tournament.watch_links.new(watch_link_params)
        link.position = next_position if params.dig(:watch_link, :position).blank?
        link.save!
        render json: watch_link_payload(link), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      def update
        return unless authorize_tournament_management!

        link = find_watch_link
        return unless link

        link.assign_attributes(watch_link_params)
        link.save!
        render json: watch_link_payload(link)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      def destroy
        return unless authorize_tournament_management!

        link = find_watch_link
        return unless link

        link.destroy!
        head :no_content
      end

      private

      def find_watch_link
        @tournament.watch_links.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Watch link not found" }, status: :not_found
        nil
      end

      def next_position
        @tournament.watch_links.maximum(:position).to_i + 1
      end

      def watch_link_params
        params.require(:watch_link).permit(:name, :url, :provider, :description, :starts_at, :position)
      end
    end
  end
end
