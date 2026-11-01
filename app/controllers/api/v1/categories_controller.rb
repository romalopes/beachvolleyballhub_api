module Api
  module V1
    class CategoriesController < ApplicationController
      before_action :set_category, only: [:show, :update, :destroy]
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      def index
        @categories = policy_scope(Category)
        render json: @categories
      end

      def show
        authorize @category
        render json: @category
      end

      def create
        authorize Category, :create?
        @category = Category.new(category_params)

        if @category.save
          render json: @category, status: :created
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @category
        if @category.update(category_params)
          render json: @category
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @category
        @category.destroy
        head :no_content
      end

      private

      def set_category
        @category = Category.find_by(slug: params[:id]) || Category.find_by(id: params[:id])
        render json: { error: "Category not found" }, status: :not_found if @category.nil?
      end

      def category_params
        params.require(:category).permit(:name)
      end
    end
  end
end