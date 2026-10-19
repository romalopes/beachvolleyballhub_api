module Api
  module V1
    class TournamentsController < ApplicationController
      include TournamentPayloads
      include TournamentManagementAuthorization

      before_action :set_tournament, only: [:show, :update, :destroy, :archive, :publish, :cancel, :restore, :participate, :destroy_participation, :follow, :unfollow]
      before_action :require_authentication, only: [:create, :update, :destroy, :archive, :publish, :cancel, :restore, :participate, :destroy_participation, :follow, :unfollow]

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
          :format,
          tournament: {},
          organisation_ids: [],
          letter_levels: [],
          division_numbers: [],
          relationship: []
        )
        # Convert array parameters - REMOVED (redundant, query object handles type checking)
        # query_params[:letter_levels] = params[:letter_levels] if params[:letter_levels].is_a?(Array)
        # query_params[:division_numbers] = params[:division_numbers] if params[:division_numbers].is_a?(Array)
        query_params[:mine] = params[:mine] == '1' if params[:mine].present?
        # Both `mine` and `relationship` narrow to the caller's own tournaments,
        # so both demand a signed-in account; the query object resolves the
        # account's rows from the account_id handed to it here.
        if query_params[:mine] || query_params[:relationship].present?
          return render json: { error: "Authentication required" }, status: :unauthorized unless Current.user
          return render json: { error: "Account required" }, status: :unprocessable_entity unless Current.user.account

          query_params[:account_id] = Current.user.account.id
        end

        relation = TournamentQuery.call(query_params)
        # Pagination
        page = [(params[:page] || 1).to_i, 1].max
        per_page = [[(params[:per_page] || 25).to_i, 1].max, 100].min
        total = relation.count
        tournaments = relation.offset((page - 1) * per_page).limit(per_page)

        render json: {
          tournaments: tournaments.map { |t| tournament_payload(t) },
          meta: {
            page: page,
            per_page: per_page,
            total: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end

      # GET /api/v1/tournaments/:id
      def show
        render json: tournament_payload(@tournament)
      end

      # POST /api/v1/tournaments
      def create
        organisation = Organisation.find_by(
          id: params[:organisation_id] || params.dig(:tournament, :organisation_id)
        )
        unless organisation
          return render json: { error: "Organisation is required" }, status: :unprocessable_entity
        end
        return unless authorize_tournament_creation!(organisation)

        tournament = TournamentCreateService.call(tournament_params)
        render json: tournament_payload(tournament), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # PATCH /api/v1/tournaments/:id
      def update
        return unless authorize_tournament_management!

        tournament = TournamentUpdateService.call(@tournament, tournament_params)
        render json: tournament_payload(tournament)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # DELETE /api/v1/tournaments/:id
      # Hard delete for unused mistakes only (Phase 4): anything with
      # participation history must be archived instead of disappearing.
      def destroy
        return unless authorize_tournament_management!

        if @tournament.participations.exists?
          return render json: {
            error: "Tournament has participations and cannot be deleted — archive it instead"
          }, status: :conflict
        end

        @tournament.destroy!
        head :no_content
      rescue ActiveRecord::InvalidForeignKey
        render json: { error: "Tournament has related records and cannot be deleted" }, status: :conflict
      end

      # PATCH /api/v1/tournaments/:id/archive
      def archive
        return unless authorize_tournament_management!

        render json: tournament_payload(TournamentArchiveService.call(@tournament))
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # PATCH /api/v1/tournaments/:id/publish
      def publish
        return unless authorize_tournament_management!

        render json: tournament_payload(TournamentPublishService.call(@tournament))
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # POST /api/v1/tournaments/:id/cancel
      def cancel
        return unless authorize_tournament_management!

        render json: tournament_payload(TournamentCancelService.call(@tournament))
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # POST /api/v1/tournaments/:id/restore
      def restore
        return unless authorize_tournament_management!

        render json: tournament_payload(TournamentRestoreService.call(@tournament))
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # POST /api/v1/tournaments/:id/participate
      def participate
        # Expect params: { role: ..., division_ids: [] }
        return render json: { error: "Account required" }, status: :unprocessable_entity unless Current.user.account

        participation = TournamentParticipationService.link_or_update_participation(
          Current.user.account.id,
          @tournament.id,
          role: participation_params[:role],
          division_ids: participation_params[:division_ids] || []
        )
        render json: participation_payload(participation)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # DELETE /api/v1/tournaments/:id/participate
      def destroy_participation
        return render json: { error: "Account required" }, status: :unprocessable_entity unless Current.user.account

        TournamentParticipationService.unlink_participation(
          Current.user.account.id,
          @tournament.id
        )
        head :no_content
      end

      # POST /api/v1/tournaments/:id/follow
      #
      # The watching-list bookmark: thinner than participation — no role, no
      # divisions — so it is created inline rather than through a service.
      # Idempotent: following twice leaves one row (model validation plus the
      # composite unique index), and the payload reports the current state.
      def follow
        return render json: { error: "Account required" }, status: :unprocessable_entity unless Current.user.account

        begin
          TournamentFollow.find_or_create_by!(account: Current.user.account, tournament: @tournament)
        rescue ActiveRecord::RecordNotUnique
          # Lost a race to the unique index — the bookmark already exists,
          # which is the outcome the caller wanted.
        end
        render json: tournament_payload(@tournament)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      # DELETE /api/v1/tournaments/:id/follow
      #
      # Unfollowing deletes the bookmark outright — a follow has no history to
      # preserve. Idempotent: unfollowing twice is still a clean no-content.
      def unfollow
        return render json: { error: "Account required" }, status: :unprocessable_entity unless Current.user.account

        TournamentFollow.find_by(account: Current.user.account, tournament: @tournament)&.destroy
        head :no_content
      end

      # GET /api/v1/tournaments/options
      def options
        scopes = Tournament.scopes.keys
        schemes = %w[letter numbered] # as per comment in TournamentQuery
        ordered_levels = %w[AAAA AAA AA A BBB BB B] # from strongest to weakest
        participation_roles = TournamentParticipation.roles.keys

        render json: {
          scopes: scopes,
          schemes: schemes,
          ordered_levels: ordered_levels,
          participation_roles: participation_roles
        }
      end

      private

      def tournament_params
        params.require(:tournament).permit(
          :name, :organisation_id, :created_by_account_id, :scope, :division_scheme,
          :publication_state, :website_url, :description,
          :location_name, :city, :state, :country, :timezone,
          :all_day, :starts_at, :ends_at
        )
      end

      def participation_params
        params.require(:participation).permit(:role, division_ids: [])
      end
    end
  end
end
