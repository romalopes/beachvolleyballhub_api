module Api
  module V1
    class OrganisationLocationsController < ApplicationController
      include LocationPayloads

      before_action :require_authentication
      before_action :set_organisation
      before_action :require_reader!, only: :index
      before_action :require_editor!, except: :index

      def index
        rows = @organisation.organisation_locations.includes(:location).order("locations.name")
        render json: {
          locations: rows.map do |row|
            location_summary(row.location).merge(
              association_id: row.id,
              notes: row.notes,
              default: row.location_id == @organisation.default_location_id
            )
          end
        }
      end

      def create
        row = @organisation.organisation_locations.find_or_initialize_by(
          location_id: association_params[:location_id]
        )
        row.notes = association_params[:notes] if association_params.key?(:notes)
        created = row.new_record?
        if row.save
          render json: {
            organisation_location: location_summary(row.location).merge(
              association_id: row.id,
              notes: row.notes
            )
          }, status: created ? :created : :ok
        else
          render json: { errors: row.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        row = @organisation.organisation_locations.find(params[:id])
        if @organisation.default_location_id == row.location_id
          return render json: { errors: [ "The default location cannot be removed" ] },
                        status: :unprocessable_entity
        end

        row.destroy!
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Organisation location not found" }, status: :not_found
      end

      private

      def set_organisation
        @organisation = Organisation.find(params[:organisation_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Organisation not found" }, status: :not_found
      end

      def require_reader!
        return if OrganisationAccess.can_read?(@organisation, Current.user)

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def require_editor!
        return if OrganisationAccess.can_edit?(@organisation, Current.user)

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def association_params
        params.require(:organisation_location).permit(:location_id, :notes)
      end
    end
  end
end
