module Api
  module V1
    # The signed-in account's own notifications: the bell count and the inbox.
    #
    # Every query is scoped through `Current.user.account`, so an account can
    # only ever read or mark its own rows — there is no id a caller can supply
    # that reaches somebody else's notification. The records are created by the
    # workflow services (see Notifications::Publisher); this controller only
    # reads them and records read state.
    class NotificationsController < ApplicationController
      include Pagination

      # The API base controller is public by default; a personal inbox is not.
      before_action :require_authentication
      before_action :set_notification, only: :mark_read

      # GET /api/v1/notifications?unread=true&event_type=training.cancelled&page=1
      def index
        scope = current_account.notifications.by_recency
        scope = scope.unread if params[:unread] == "true"
        scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?

        notifications, meta = paginate(scope)
        render json: { data: notifications.map { |notification| serialize(notification) }, meta: meta }
      end

      # GET /api/v1/notifications/unread_count
      #
      # A single COUNT for the badge. `private, no-store` keeps shared caches
      # (Cloudflare, proxies) from ever storing one account's count for another.
      def unread_count
        response.headers["Cache-Control"] = "private, no-store"
        render json: { unread_count: current_account.notifications.unread.count }
      end

      # PATCH /api/v1/notifications/:id/mark_read
      def mark_read
        @notification.mark_read!
        render json: serialize(@notification)
      end

      # PATCH /api/v1/notifications/mark_all_read
      def mark_all_read
        marked = current_account.notifications.unread
                                 .update_all(read_at: Time.current, updated_at: Time.current)
        render json: { marked: marked }
      end

      private

      def current_account
        Current.user.account || raise(ActiveRecord::RecordNotFound)
      end

      def set_notification
        @notification = current_account.notifications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Notification not found" }, status: :not_found
      end

      def serialize(notification)
        {
          id: notification.id,
          event_type: notification.event_type,
          title: notification.title,
          message: notification.message,
          target_path: notification.target_path,
          target_label: notification.target_label,
          metadata: notification.metadata,
          read: notification.read?,
          read_at: notification.read_at,
          created_at: notification.created_at,
          actor: notification.actor_account && {
            id: notification.actor_account_id,
            name: notification.actor_account.full_name
          }
        }
      end
    end
  end
end
