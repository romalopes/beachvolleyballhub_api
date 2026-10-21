# Delivers one cancellation email and records that it was sent.
#
# The participant row is locked and re-checked so two retries (or a duplicate
# enqueue) cannot send the same email twice. The job only ever loads ids, never
# ActiveRecord objects, so it is safe across the queue boundary.
class TrainingSessionCancellationJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(participant_id)
    participant = TrainingSessionParticipant
                    .includes(:training_session,
                              player_profile: { account: :user })
                    .find_by(id: participant_id)
    return if participant.nil? || participant.cancellation_notified_at.present?

    session = participant.training_session
    return unless session&.cancelled?

    user = participant.player_profile&.account&.user
    return if user&.email_address.blank?

    participant.with_lock do
      return if participant.cancellation_notified_at.present?

      TrainingSessionsMailer.cancelled(session, participant).deliver_now
      participant.update!(cancellation_notified_at: Time.current)
    end
  rescue StandardError => e
    Rails.logger.error(
      "[recurring-training] cancellation email failed for participant " \
      "#{participant_id}: #{e.class}: #{e.message}"
    )
    raise
  end
end
