class AddCancellationNotifiedAtToTrainingSessionParticipants < ActiveRecord::Migration[8.1]
  # Cancellation emails are best-effort and must not be sent twice when a job
  # retries. The timestamp is the per-participant idempotency guard.
  def change
    add_column :training_session_participants, :cancellation_notified_at, :datetime
  end
end
