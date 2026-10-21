# Cancels explicitly selected occurrences of a series.
#
# Cancellation is never a deletion: the row keeps its recurrence_key so a later
# generation run treats it as a tombstone. Completed occurrences are refused,
# already-cancelled ones are reported as skipped, and ids from another series
# are never touched.
class TrainingSeriesCanceller
  Result = Struct.new(:affected, :skipped, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end

    def affected_ids
      affected.map(&:id)
    end
  end

  def initialize(series, session_ids:, reason:, actor: nil, notify_participants: false)
    @series = series
    @session_ids = sanitize_ids(session_ids)
    @reason = reason.to_s.strip
    @actor = actor
    @notify_participants = notify_participants
  end

  def call
    errors = []
    errors << "Select at least one occurrence" if session_ids.empty?
    errors << "A cancellation reason is required" if reason.blank?
    return Result.new(affected: [], skipped: [], errors: errors) if errors.any?

    affected = []
    skipped = []

    ActiveRecord::Base.transaction do
      sessions = series.training_sessions.where(id: session_ids).to_a
      found_ids = sessions.map(&:id)
      (session_ids - found_ids).each do |id|
        skipped << { id: id, reason: "not_in_series" }
      end

      sessions.each do |session|
        unless session.cancellable?
          reason_code = session.cancelled? ? "already_cancelled" : "not_cancellable"
          skipped << { id: session.id, reason: reason_code }
          next
        end

        session.mark_cancelled!(reason: reason, actor: actor)
        affected << session
      end
    end

    notify(affected) if notify_participants && affected.any?

    Result.new(affected: affected, skipped: skipped, errors: [])
  end

  private

  attr_reader :series, :session_ids, :reason, :actor, :notify_participants

  def sanitize_ids(ids)
    Array(ids).map(&:to_i).select(&:positive?).uniq
  end

  def notify(sessions)
    TrainingSessionCancellationNotifier.call(sessions)
  rescue StandardError => e
    # The cancellation is already committed; a queue failure must not turn a
    # successful cancellation into a 500.
    Rails.logger.error(
      "[recurring-training] failed to enqueue cancellation emails: #{e.class}: #{e.message}"
    )
  end
end
