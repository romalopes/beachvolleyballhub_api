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

    # A public contact enquiry (IDENTITY-259) is platform-level support work, so
    # its recipients are the platform Admins and Curators — never every coach and
    # never organisation members. `event_key` is derived from the message id, so
    # a retried delivery job cannot notify the same person twice.
    #
    # The caller (ContactMessageDeliveryJob) resolves the recipients, because
    # "who is platform staff" is a query about Users; this rule only describes
    # the event.
    def contact_message_received(message, recipients:)
      Notifications::Publisher.publish(
        recipients: recipients,
        event_type: "contact.message.received",
        event_key: "contact_message:#{message.id}:received",
        title: "New contact message",
        message: "#{message.name} sent a #{message.contact_type_label.downcase}: #{message.subject}",
        notifiable: message,
        target_path: "/settings/contact-messages/#{message.id}",
        target_label: message.subject
      )
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

    # Analysis Request events (IDENTITY-265)
    def analysis_request_submitted(request)
      recipients = crew_accounts + [request.account].compact
      Notifications::Publisher.publish(
        recipients: recipients.uniq,
        event_type: "analysis_request.submitted",
        event_key: "analysis_request:#{request.id}:submitted",
        title: "New analysis request",
        message: "#{request.submitter_name} submitted \"#{request.title}\"",
        actor: request.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def analysis_request_accepted(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.accepted",
        event_key: "analysis_request:#{request.id}:accepted",
        title: "Request accepted",
        message: "Your analysis request \"#{request.title}\" was accepted.",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
      crew_notify(request, "analysis_request.accepted", "Request accepted", "Request \"#{request.title}\" was accepted.")
    end

    def analysis_request_rejected(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.rejected",
        event_key: "analysis_request:#{request.id}:rejected",
        title: "Request rejected",
        message: "Your analysis request \"#{request.title}\" was rejected: #{request.rejection_reason}",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def analysis_request_quoted(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.quoted",
        event_key: "analysis_request:#{request.id}:quoted",
        title: "Price quote",
        message: "Your analysis request \"#{request.title}\" received a quote of #{request.price_aud}.",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def analysis_request_coach_assigned(request)
      return unless request.assigned_coach_profile&.account
      Notifications::Publisher.publish(
        recipients: [request.assigned_coach_profile.account],
        event_type: "analysis_request.coach_assigned",
        event_key: "analysis_request:#{request.id}:coach_assigned",
        title: "Request assigned",
        message: "You have been assigned to analysis request \"#{request.title}\" (#{request.reference}).",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/coach/analysis-requests/#{request.id}",
        target_label: request.reference
      )
      crew_notify(request, "analysis_request.coach_assigned", "Coach assigned", "Request \"#{request.title}\" assigned to #{request.assigned_coach_profile.display_name}.")
    end

    def analysis_request_message_created(message)
      # Internal notes are staff-only; the model also guards this, but the
      # publisher must never leak one to the submitter even if called directly.
      return if message.internal?

      request = message.analysis_request
      recipients =
        if message.from_submitter?
          # The crew plus the assigned coach, who needs to know the submitter
          # replied.
          crew_accounts + [ request.assigned_coach_profile&.account ].compact
        else
          [ request.account ].compact
        end

      Notifications::Publisher.publish(
        recipients: recipients.uniq,
        event_type: "analysis_request.message",
        event_key: "analysis_request:#{request.id}:message:#{message.id}",
        title: message.from_submitter? ? "New message" : "New message from the team",
        message: "New message from #{message.author_name} on request #{request.reference}",
        actor: message.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def analysis_request_invoice_sent(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.invoice_sent",
        event_key: "analysis_request:#{request.id}:invoice_sent",
        title: "Invoice sent",
        message: "Invoice for request \"#{request.title}\" (#{request.reference}) has been sent.",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def analysis_request_payment_received(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.payment_received",
        event_key: "analysis_request:#{request.id}:payment_received",
        title: "Payment received",
        message: "Payment for request \"#{request.title}\" (#{request.reference}) has been received.",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
      crew_notify(request, "analysis_request.payment_received", "Payment received", "Payment received for request \"#{request.title}\".")
    end

    def analysis_request_overdue(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.overdue",
        event_key: "analysis_request:#{request.id}:overdue",
        title: "Payment overdue",
        message: "Payment for request \"#{request.title}\" (#{request.reference}) is overdue.",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
      crew_notify(request, "analysis_request.overdue", "Payment overdue", "Payment overdue for request \"#{request.title}\".")
    end

    def analysis_request_work_started(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.work_started",
        event_key: "analysis_request:#{request.id}:work_started",
        title: "Work started",
        message: "Analysis work has started on request \"#{request.title}\" (#{request.reference}).",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def analysis_request_completed(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.completed",
        event_key: "analysis_request:#{request.id}:completed",
        title: "Analysis completed",
        message: "Your analysis request \"#{request.title}\" (#{request.reference}) has been completed.",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
      crew_notify(request, "analysis_request.completed", "Analysis completed", "Request \"#{request.title}\" completed.")
    end

    def analysis_request_deliverable_uploaded(request)
      Notifications::Publisher.publish(
        recipients: [request.account].compact,
        event_type: "analysis_request.deliverable_uploaded",
        event_key: "analysis_request:#{request.id}:deliverable",
        title: "Deliverable uploaded",
        message: "New deliverable available for request \"#{request.title}\" (#{request.reference}).",
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    # Helpers below are module functions like every other rule in this module:
    # `private` would silently drop them from the module_function set.
    #
    # Mirrors AnalysisRequestRecipients: an explicit crew list wins; with none
    # configured, the platform staff (admin/curator accounts) are the team, so a
    # new submission is never silently unannounced in the bell either.
    def crew_accounts
      raw = AppSetting.find_by(key: "analysis_request_crew_account_ids")&.value.to_s
      account_ids = raw.split(",").map(&:strip).reject(&:empty?)
      return Account.where(id: account_ids) if account_ids.any?

      staff_accounts
    end

    def staff_accounts
      Account.joins(user: { user_roles: :role })
             .where(roles: { name: %w[admin curator] })
             .distinct
    end

    def crew_notify(request, event_type, title, message)
      Notifications::Publisher.publish(
        recipients: crew_accounts,
        event_type: event_type,
        event_key: "analysis_request:#{request.id}:#{event_type.split('.').last}",
        title: title,
        message: message,
        actor: Current.user&.account,
        notifiable: request,
        target_path: "/admin/analysis-requests/#{request.id}",
        target_label: request.reference
      )
    end

    def submitter_name(request)
      request.account ? request.account.full_name : request.guest_name
    end
  end
end
