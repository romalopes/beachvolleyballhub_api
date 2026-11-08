module Api
  module V1
    module Admin
      class DisciplinesController < ApplicationController
        include RequestLogging
        before_action :authorize_admin!
        before_action :set_discipline, only: [ :show, :update, :destroy ]

        def index
          @disciplines = Discipline.includes(:skills).order(:name)
          render json: @disciplines
        end

        def show
          render json: @discipline
        end

        def create
          @discipline = Discipline.new(discipline_params)

          if @discipline.save
            render json: @discipline, status: :created
          else
            render json: { errors: @discipline.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @discipline.update(discipline_params)
            render json: @discipline
          else
            render json: { errors: @discipline.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          if @discipline.skills.any? && params[:confirm_destroy] != @discipline.id.to_s
            render json: {
              error: "Cannot delete this discipline because it contains #{@discipline.skills.count} skill(s). Set confirm_destroy=#{@discipline.id} to force removal (skills will also be deleted)."
            }, status: :unprocessable_entity
          else
            @discipline.destroy
            head :no_content
          end
        end

        private

        def set_discipline
          @discipline = Discipline.find_by(slug: params[:id]) ||
                      Discipline.find_by(id: params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Discipline not found" }, status: :not_found
        end

        def discipline_params
          params.require(:discipline).permit(:name)
        end
      end
    end
  end
end
