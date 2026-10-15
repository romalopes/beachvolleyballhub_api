module Api
  module V1
    # Division management for tournament admins (Phase 4):
    #   POST   /api/v1/tournaments/:tournament_id/divisions
    #   PATCH  /api/v1/tournaments/:tournament_id/divisions/:id
    #   DELETE /api/v1/tournaments/:tournament_id/divisions/:id
    #
    # The rules live in TournamentDivisionService — scheme match and code
    # uniqueness are model validations; referenced codes are locked, the final
    # active division is protected, and referenced divisions are retired rather
    # than deleted.
    class TournamentDivisionsController < ApplicationController
      include TournamentPayloads
      include TournamentManagementAuthorization

      before_action :set_tournament
      before_action :require_authentication

      def create
        return unless authorize_tournament_management!

        division = TournamentDivisionService.create(@tournament, division_params)
        render json: division_payload(division), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique
        render json: { errors: ["That division code already exists in this tournament"] }, status: :conflict
      end

      def update
        return unless authorize_tournament_management!

        division = find_division
        return unless division

        updated = TournamentDivisionService.update(division, division_params)
        render json: division_payload(updated)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique
        render json: { errors: ["That division code already exists in this tournament"] }, status: :conflict
      end

      def destroy
        return unless authorize_tournament_management!

        division = find_division
        return unless division

        result = TournamentDivisionService.destroy(division)
        if result[:retired]
          # Referenced divisions are retired, not deleted — the row stays as the
          # history participants selected against.
          render json: division_payload(result[:division])
        else
          head :no_content
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: invalid_record_errors(e) }, status: :unprocessable_entity
      end

      private

      def find_division
        @tournament.divisions.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Division not found" }, status: :not_found
        nil
      end

      def division_params
        params.require(:division).permit(:letter_level, :division_number, :active)
      end
    end
  end
end
