module Api
  module V1
    module Admin
      # Plan catalogue administration (IDENTITY-116, Phase 4 admin surface).
      #
      # Admin-only, and deliberately non-destructive: a plan referenced by billing
      # records or history is deactivated rather than deleted, so no customer's
      # invoice history loses its plan. Prices here are catalogue/display values —
      # the amount Stripe charges is still its own Price, resolved server-side.
      class SubscriptionsController < ApplicationController
        before_action :authorize_admin!
        before_action :set_subscription, only: %i[show update destroy features]

        PERMITTED = %i[
          name slug description active visible popular is_default position currency
          yearly_price_cents owner_scope included_users history_limit stripe_price_id
        ].freeze

        def index
          plans = Subscription.ordered
                             .includes(subscription_subscription_features: :subscription_feature)
          render json: { data: plans.map { |plan| ::Billing::Presenter.plan(plan) } }
        end

        def show
          render json: { subscription: ::Billing::Presenter.plan(@subscription) }
        end

        def create
          plan = Subscription.new(subscription_params)
          if plan.save
            render json: { subscription: ::Billing::Presenter.plan(plan) }, status: :created
          else
            render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          make_single_default! if subscription_params[:is_default].to_s == "true"

          if @subscription.update(subscription_params)
            render json: { subscription: ::Billing::Presenter.plan(@subscription.reload) }
          else
            render json: { errors: @subscription.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # Deactivation instead of deletion once the plan has any history, which is
        # what keeps old invoices and subscription rows explicable.
        def destroy
          if referenced?(@subscription)
            @subscription.update!(active: false, visible: false)
            render json: {
              deactivated: true,
              subscription: ::Billing::Presenter.plan(@subscription),
              message: "The plan has billing history and was deactivated instead of deleted."
            }
          else
            @subscription.destroy!
            head :no_content
          end
        end

        # PUT /api/v1/admin/subscriptions/:id/features
        # Body: { feature_ids: [3, 1, 2] } — order is the display order.
        def features
          ids = Array(params[:feature_ids]).map(&:to_i).uniq

          ActiveRecord::Base.transaction do
            @subscription.subscription_subscription_features.destroy_all
            ids.each_with_index do |feature_id, index|
              @subscription.subscription_subscription_features.create!(
                subscription_feature_id: feature_id,
                position: index
              )
            end
          end

          render json: { subscription: ::Billing::Presenter.plan(@subscription.reload) }
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: [ e.message ] }, status: :unprocessable_entity
        end

        private

        def set_subscription
          @subscription = Subscription.find_by(id: params[:id]) ||
                          Subscription.find_by(slug: params[:id])
          render json: { error: "Subscription plan not found" }, status: :not_found if @subscription.nil?
        end

        def subscription_params
          params.require(:subscription).permit(*PERMITTED)
        end

        def referenced?(plan)
          plan.billing_subscriptions.exists? || plan.subscription_histories.exists?
        end

        def make_single_default!
          Subscription.where.not(id: @subscription.id).update_all(is_default: false)
        end
      end
    end
  end
end
