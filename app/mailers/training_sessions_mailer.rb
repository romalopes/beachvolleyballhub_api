# Participant-facing cancellation notice for a recurring training occurrence.
class TrainingSessionsMailer < ApplicationMailer
  def cancelled(session, participant)
    @session = session
    @participant = participant
    @user = participant.player_profile&.account&.user
    @time_zone = session.training_series&.time_zone || Time.zone.name
    @reason = session.cancellation_reason

    mail(
      to: @user.email_address,
      subject: "Training cancelled: #{session.title}"
    )
  end
end
