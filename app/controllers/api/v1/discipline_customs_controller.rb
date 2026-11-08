module Api
  module V1
    # Coach-authored rubrics outside the club catalogue ("Mental game").
    #
    # Listing is deliberately narrower than "every row": a private custom
    # discipline belongs to its creator, so another coach must not be able to
    # discover it through the index — which is the rule `usable_by?` encodes,
    # applied here as a scope instead of a per-row filter after pagination.
    class DisciplineCustomsController < ApplicationController
      include ContentAuthorization

      before_action :require_authentication
      before_action :require_training_manager!
      before_action :require_content_creator!, only: :create
      before_action :set_discipline_custom, only: %i[show update]

      def index
        rows = usable_scope
        rows = rows.where(created_by_id: Current.user.id) if params[:mine].present?

        render json: rows.map(&:metadata)
      end

      def show
        render json: @discipline_custom.metadata
      end

      def create
        @discipline_custom = DisciplineCustom.new(discipline_custom_params.merge(created_by: Current.user))

        if @discipline_custom.save
          render json: @discipline_custom.metadata, status: :created
        else
          render json: { errors: @discipline_custom.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        return render json: { error: "Forbidden" }, status: :forbidden unless manageable?

        if @discipline_custom.update(discipline_custom_params)
          render json: @discipline_custom.metadata
        else
          render json: { errors: @discipline_custom.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_discipline_custom
        @discipline_custom = usable_scope.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        # Not visible to this caller is the same answer as not existing.
        render json: { error: "Custom discipline not found" }, status: :not_found
      end

      def discipline_custom_params
        params.require(:discipline_custom).permit(:name, :visibility)
      end

      def manageable?
        @discipline_custom.manageable_by?(Current.user)
      end

      # What this caller may select from: everything for oversight, otherwise
      # the shared catalogue plus rows they authored themselves.
      def usable_scope
        user = Current.user
        return DisciplineCustom.none if user.nil?
        return DisciplineCustom.all if Assessment.oversight?(user)

        DisciplineCustom.where(visibility: "shared")
                      .or(DisciplineCustom.where(created_by_id: user.id))
      end
    end
  end
end
