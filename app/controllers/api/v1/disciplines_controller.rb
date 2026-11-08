module Api
  module V1
    class DisciplinesController < ApplicationController
      before_action :set_discipline, only: [ :show, :update, :destroy ]
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      def index
        @disciplines = policy_scope(Discipline)
        render json: @disciplines
      end

      def show
        authorize @discipline
        render json: @discipline
      end

      def create
        authorize Discipline, :create?
        @discipline = Discipline.new(discipline_params)

        if @discipline.save
          render json: @discipline, status: :created
        else
          render json: { errors: @discipline.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @discipline
        if @discipline.update(discipline_params)
          render json: @discipline
        else
          render json: { errors: @discipline.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @discipline
        @discipline.destroy
        head :no_content
      end

      private

      def set_discipline
        @discipline = Discipline.find_by(slug: params[:id]) || Discipline.find_by(id: params[:id])
        render json: { error: "Discipline not found" }, status: :not_found if @discipline.nil?
      end

      def discipline_params
        params.require(:discipline).permit(:name)
      end
    end
  end
end
