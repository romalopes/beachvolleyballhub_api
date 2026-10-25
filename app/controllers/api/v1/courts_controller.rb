module Api
  module V1
    class CourtsController < ApplicationController
      include LocationPayloads

      before_action :require_authentication
      before_action :set_location
      before_action :require_location_oversight!, except: :index
      before_action :set_court, only: %i[update destroy]

      def index
        render json: { courts: @location.courts.ordered.map(&:summary) }
      end

      def create
        court = @location.courts.new(court_params)
        if court.save
          render json: { court: court.summary }, status: :created
        else
          render json: { errors: court.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @court.update(court_params)
          render json: { court: @court.summary }
        else
          render json: { errors: @court.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @court.update!(status: "archived")
        render json: { court: @court.summary }
      end

      private

      def set_location
        @location = Location.find(params[:location_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Location not found" }, status: :not_found
      end

      def set_court
        @court = @location.courts.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Court not found" }, status: :not_found
      end

      def require_location_oversight!
        return if location_oversight?

        render json: { error: "Only a curator or admin can manage courts" }, status: :forbidden
      end

      def court_params
        params.require(:court).permit(:name, :latitude, :longitude, :access_instructions, :status)
      end
    end
  end
end
