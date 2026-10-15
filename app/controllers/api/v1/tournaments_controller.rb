module Api
  module V1
    class TournamentsController < ApplicationController
      before_action :set_tournament, only: [:show, :update, :archive, :publish]
      before_action :require_authentication, only: [:create, :update, :archive, :publish, :participate]

      # GET /api/v1/tournaments
      def index
        query_params = params.permit(
          :search,
          :scope,
          :organisation_id,
          :division_scheme,
          :location,
          :temporal_status,
          :mine,
          :publication_state,
          :starts_at,
          :ends_at,
          :page,
          :per_page,
          letter_levels: [],
          division_numbers: []
        )
        # Convert array parameters - REMOVED (redundant, query object handles type checking)
        # query_params[:letter_levels] = params[:letter_levels] if params[:letter_levels].is_a?(Array)
        # query_params[:division_numbers] = params[:division_numbers] if params[:division_numbers].is_a?(Array)
        query_params[:mine] = params[:mine] == '1' if params[:mine].present?
        query_params[:account_id] = Current_user.account.id if query_params[:mine] && Current_user.account

        relation = TournamentQuery.call(query_params)
        # Pagination
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 25).to_i, 100].min
        tournaments = relation.page(page).per(per_page)

        render json: {
          tournaments: tournaments.map { |t| tournament_payload(t) },
          meta: {
            page: page,
            per_page: per_page,
            total: relation.count,
            total_pages: relation.count.to_f / per_page
          }
        }
      # GET /api/v1/tournaments/:id
      def show
        render json: tournament_payload(@tournament)
      end

      # POST /api/v1/tournaments
      def create
        authorize_admin_for_organisation!(params[:organisation_id])
        tournament = TournamentCreateService.call(tournament_params)
        render json: tournament_payload(tournament), status: :created
      end

      # PATCH /api/v1/tournaments/:id
      def update
        authorize_tournament_management!(@tournament)
        tournament = TournamentUpdateService.call(@tournament, tournament_params)
        render json: tournament_payload(tournament)
      end

      # PATCH /api/v1/tournaments/:id/archive
      def archive
        authorize_tournament_management!(@tournament)
        tournament = TournamentArchiveService.call(@tournament)
        render json: tournament_payload(tournament)
      end

      # PATCH /api/v1/tournaments/:id/publish
      def publish
        authorize_tournament_management!(@tournament)
        tournament = TournamentPublishService.call(@tournament)
        render json: tournament_payload(tournament)
      end

      # POST /api/v1/tournaments/:id/participate
      def participate
        # Expect params: { role: ..., division_ids: [] }
        participation = TournamentParticipationService.call(
          tournament: @tournament,
          account_id: Current.user.account.id,
          params: participation_params
        )
        render json: participation_payload(participation)
      end

      private

      def set_tournament
        @tournament = Tournament.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Tournament not found" }, status: :not_found
      end

      def tournament_params
        params.require(:tournament).permit(
          :name, :organisation_id, :created_by_account_id, :scope, :division_scheme,
          :publication_state, :website_url, :description,
          :location_name, :city, :state, :country, :timezone,
          :all_day, :starts_at, :ends_at
        )
      end

      def participation_params
        params.permit(:role, division_ids: [])
      end

      def tournament_payload(tournament)
        {
          id: tournament.id,
          name: tournament.name,
          organisation: {
            id: tournament.organisation.id,
            name: tournament.organisation.name,
            acronym: tournament.organisation.acronym
          },
          scope: tournament.scope,
          division_scheme: tournament.division_scheme,
          publication_state: tournament.publication_state,
          website_url: tournament.website_url,
          description: tournament.description,
          location_name: tournament.location_name,
          city: tournament.city,
          state: tournament.state,
          country: tournament.country,
          timezone: tournament.timezone,
          all_day: tournament.all_day,
          starts_at: tournament.starts_at,
          ends_at: tournament.ends_at,
          created_by_account_id: tournament.created_by_account_id,
          divisions: tournament.divisions.active.map { |d| division_payload(d) },
          participations: tournament.participations.map { |p| participation_payload(p) },
          watch_links: tournament.watch_links.map { |l| watch_link_payload(l) }
        }
      end

      def division_payload(division)
        {
          id: division.id,
          letter_level: division.letter_level,
          division_number: division.division_number,
          active: division.active,
          strength_order: division.strength_order,
          division_code: division.division_code
        }
      end

      def participation_payload(participation)
        {
          id: participation.id,
          account_id: participation.account_id,
          role: participation.role,
          created_at: participation.created_at
        }
      end

      def watch_link_payload(link)
        {
          id: link.id,
          url: link.url,
          link_type: link.link_type,
          position: link.position,
          active: link.active
        }
      end

      def authorize_admin_for_organisation!(organisation_id)
        organisation = Organisation.find(organisation_id)
        unless Current.user.account&.id == organisation.account_id || Current.user.admin?
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end

      def authorize_tournament_management!(tournament)
        unless Current.user.account&.id == tournament.organisation.account_id || Current.user.admin?
          render json: { error: "Forbidden" }, status: :forbidden
        end
      end
    end
  end
end
      end