# Enqueues cancellation emails for a set of cancelled sessions.
#
# Only participants whose PlayerProfile is linked to an Account with an email
# address can be reached; accountless participants simply keep the cancellation
# visible in the schedule. The per-participant timestamp makes the job
# idempotent even if the queue retries.
class TrainingSessionCancellationNotifier
  def self.call(sessions)
    Array(sessions).each do |session|
      next unless session.cancelled?

      session.training_session_participants
             .includes(player_profile: { account: :user })
             .find_each do |participant|
        next if participant.cancellation_notified_at.present?

        email = participant.player_profile&.account&.user&.email_address
        next if email.blank?

        TrainingSessionCancellationJob.perform_later(participant.id)
      end
    end
  end
end
