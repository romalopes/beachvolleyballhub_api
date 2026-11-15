module Api
  module V1
    module Admin
      # Read-only billing inspection for administrators (IDENTITY-116).
      #
      # Three views:
      #   * the local billing records, so support can see who is on what;
      #   * webhook processing history, so a failed delivery is visible;
      #   * configuration diagnostics, which report presence of settings by name
      #     and never a secret value.
      class BillingRecordsController < ApplicationController
        include Pagination
        before_action :authorize_admin!

        def index
          scope = BillingSubscription.includes(:subscription).order(created_at: :desc)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(billable_type: params[:owner_type]) if params[:owner_type].present?

          records, meta = paginate(scope)
          render json: { data: records.map { |record| record_payload(record) }, meta: meta }
        end

        def events
          scope = BillingEvent.recent
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?

          records, meta = paginate(scope)
          render json: {
            data: records.map { |event| event_payload(event) },
            meta: meta
          }
        end

        def diagnostics
          render json: {
            billing: ::Billing::Configuration.diagnostics,
            counts: {
              billing_subscriptions: BillingSubscription.count,
              billing_customers: BillingCustomer.count,
              billing_events: BillingEvent.count,
              failed_events: BillingEvent.failures.count,
              open_checkout_sessions: BillingCheckoutSession.open_sessions.count
            }
          }
        end

        private

        def record_payload(record)
          {
            id: record.id,
            owner: {
              type: record.billable_type,
              id: record.billable_id,
              name: ::Billing::OwnerContact.name(record.billable)
            },
            plan: ::Billing::Presenter.plan_summary(record.subscription),
            status: record.status,
            stripe_customer_id: record.stripe_customer_id,
            stripe_subscription_id: record.stripe_subscription_id,
            current_period_end: record.current_period_end,
            cancel_at_period_end: record.cancel_at_period_end?,
            grace_period_ends_at: record.grace_period_ends_at,
            last_synced_at: record.last_synced_at,
            created_at: record.created_at,
            updated_at: record.updated_at
          }
        end

        def event_payload(event)
          {
            id: event.id,
            stripe_event_id: event.stripe_event_id,
            event_type: event.event_type,
            stripe_object_id: event.stripe_object_id,
            status: event.status,
            attempts: event.attempts,
            error_message: event.error_message,
            received_at: event.received_at,
            processed_at: event.processed_at,
            created_at: event.created_at
          }
        end
      end
    end
  end
end
