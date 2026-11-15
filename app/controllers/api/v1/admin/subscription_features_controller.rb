module Api
  module V1
    module Admin
      # Feature catalogue administration (IDENTITY-116, Phase 4 admin surface).
      #
      # Features are the stable slugs the API enforces. Deleting one that a plan or
      # history references would silently remove an entitlement, so it is
      # deactivated instead.
      class SubscriptionFeaturesController < ApplicationController
        before_action :authorize_admin!
        before_action :set_feature, only: %i[update destroy]

        PERMITTED = %i[name slug description active position].freeze

        def index
          features = SubscriptionFeature.ordered
          render json: { data: features.map { |feature| ::Billing::Presenter.feature(feature) } }
        end

        def create
          feature = SubscriptionFeature.new(feature_params)
          if feature.save
            render json: { feature: ::Billing::Presenter.feature(feature) }, status: :created
          else
            render json: { errors: feature.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @feature.update(feature_params)
            render json: { feature: ::Billing::Presenter.feature(@feature) }
          else
            render json: { errors: @feature.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          if @feature.subscription_subscription_features.exists?
            @feature.update!(active: false)
            render json: {
              deactivated: true,
              feature: ::Billing::Presenter.feature(@feature),
              message: "The feature is attached to plans and was deactivated instead of deleted."
            }
          else
            @feature.destroy!
            head :no_content
          end
        end

        private

        def set_feature
          @feature = SubscriptionFeature.find_by(id: params[:id]) ||
                     SubscriptionFeature.find_by(slug: params[:id])
          render json: { error: "Subscription feature not found" }, status: :not_found if @feature.nil?
        end

        def feature_params
          params.require(:subscription_feature).permit(*PERMITTED)
        end
      end
    end
  end
end
