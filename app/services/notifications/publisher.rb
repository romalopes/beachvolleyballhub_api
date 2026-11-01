module Notifications
  # The single entry point for creating in-app notifications.
  #
  # Callers describe an event once (recipients + a stable event key) and the
  # publisher handles the parts that must be consistent everywhere:
  #
  #   * recipient preference filtering — a muted event type writes nothing;
  #   * idempotency — `create_or_find_by!` on (account, event_key) means the same
  #     transition can be replayed without duplicating a recipient's row;
  #   * reporting which rows were actually created, so a later email/push channel
  #     can act only on genuinely new notifications.
  #
  # It deliberately does no authorization: choosing recipients is the caller's
  # job and belongs next to the workflow that knows who is affected.
  class Publisher
    Result = Data.define(:created, :notification)

    def self.publish(**attributes)
      new(**attributes).call
    end

    def initialize(recipients:, event_type:, event_key:, title:, message:, actor: nil,
                   notifiable: nil, target_path: nil, target_label: nil, metadata: {})
      @recipients = Array(recipients).compact.uniq
      @event_type = event_type.to_s
      @event_key = event_key.to_s
      @title = title
      @message = message
      @actor = actor
      @notifiable = notifiable
      @target_path = target_path
      @target_label = target_label
      @metadata = metadata
    end

    def call
      recipients.filter_map do |account|
        preference = account.notification_preference || account.build_notification_preference
        next unless preference.event_enabled?(event_type)

        notification = account.notifications.create_or_find_by!(event_key: event_key) do |row|
          row.assign_attributes(
            event_type: event_type,
            title: title,
            message: message,
            actor_account: actor,
            notifiable: notifiable,
            target_path: target_path,
            target_label: target_label,
            metadata: metadata
          )
        end
        Result.new(created: notification.previously_new_record?, notification: notification)
      end
    end

    private

    attr_reader :recipients, :event_type, :event_key, :title, :message, :actor,
                :notifiable, :target_path, :target_label, :metadata
  end
end
