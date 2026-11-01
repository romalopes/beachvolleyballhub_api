module Notifications
  # Domain event rules: "who is told what, when".
  #
  # Controllers call these after a workflow has persisted successfully (never
  # from model callbacks), which keeps notification creation out of the
  # transaction that changes the domain and makes the recipient rules explicit
  # and testable. The rules here are intentionally narrow — training and
  # membership workflows — and each event carries a stable key derived from the
  # record ids and the transition, so replays dedupe.
  module WorkflowEvents
    module_function

    # Training invitation / reschedule / cancellation for the session's
    # participants. `previous` is a snapshot taken before the update (status,
    # times and participant account ids), so the transition can be classified.
    def training_changed(training, actor:, previous: {})
      accounts = participant_accounts(training)
      return if accounts.empty?

      if training.cancelled? && previous["status"] != "cancelled"
        publish_training(training, accounts, actor, "training.cancelled", "Training cancelled",
                         "#{training.title} has been cancelled.", "cancelled-#{training.updated_at.to_i}")
      elsif time_changed?(training, previous)
        publish_training(training, accounts, actor, "training.rescheduled", "Training rescheduled",
                         "#{training.title} has a new time.", "rescheduled-#{training.updated_at.to_i}")
      else
        added_ids = participant_account_ids(training) - Array(previous["participant_account_ids"])
        added = accounts.select { |account| added_ids.include?(account.id) }
        if added.any?
          publish_training(training, added, actor, "training.invited", "Training invitation",
                           "You were added to #{training.title}.", "participants-#{training.updated_at.to_i}")
        end
      end
    end

    # A pending self-service join request is routed to the people who can approve
    # it (an organisation's active owner/administrators, a group's owner).
    def membership_requested(container, membership, actor:)
      Notifications::Publisher.publish(
        recipients: approver_accounts(container),
        event_type: "membership.requested",
        event_key: "#{container.class.name.underscore}:#{container.id}:membership:#{membership.id}:requested",
        title: "Membership request",
        message: "#{membership.account&.full_name.presence || 'A member'} requested to join #{container.name}.",
        actor: actor,
        notifiable: container,
        target_path: container_path(container),
        target_label: container.name
      )
    end

    # The decision is told to the requester. `decision` is "approved" or
    # "rejected"; only the requester is a recipient, never the whole roster.
    def membership_decided(container, membership, actor:, decision:)
      return unless membership.account

      Notifications::Publisher.publish(
        recipients: [ membership.account ],
        event_type: "membership.#{decision}",
        event_key: "#{container.class.name.underscore}:#{container.id}:membership:#{membership.id}:#{decision}",
        title: "Membership #{decision}",
        message: "Your request to join #{container.name} was #{decision}.",
        actor: actor,
        notifiable: container,
        target_path: container_path(container),
        target_label: container.name
      )
    end

    def publish_training(training, accounts, actor, event_type, title, message, suffix)
      Notifications::Publisher.publish(
        recipients: accounts,
        event_type: event_type,
        event_key: "training:#{training.id}:#{suffix}",
        title: title,
        message: message,
        actor: actor,
        notifiable: training,
        target_path: "/training/#{training.id}",
        target_label: training.title,
        metadata: { starts_at: training.starts_at, ends_at: training.ends_at }
      )
    end

    # Participants reference the PlayerProfile (domain identity), so the account
    # is reached through the profile. A profile without an account is simply not
    # a recipient: there is nobody to notify yet.
    def participant_accounts(training)
      training.training_session_participants.includes(player_profile: :account)
              .filter_map { |participant| participant.player_profile.account }.uniq
    end

    def participant_account_ids(training)
      participant_accounts(training).map(&:id)
    end

    def time_changed?(training, previous)
      (previous.key?("starts_at") && previous["starts_at"] != training.starts_at) ||
        (previous.key?("ends_at") && previous["ends_at"] != training.ends_at)
    end

    def approver_accounts(container)
      case container
      when Organisation
        container.organisation_memberships.active.manageable.includes(:account).filter_map(&:account)
      when Group
        container.group_memberships.owners.includes(:account).filter_map(&:account)
      else
        []
      end
    end

    def container_path(container)
      if container.is_a?(Organisation)
        "/organisations/#{container.slug || container.id}"
      else
        "/groups/#{container.id}"
      end
    end
  end
end
