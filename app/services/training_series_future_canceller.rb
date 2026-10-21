# Cancels every still-cancellable occurrence of a series from a local date
# onward. It exists so the dashboard does not have to enumerate ids for the
# "cancel the rest" action, while the actual cancellation rules stay in
# TrainingSeriesCanceller.
class TrainingSeriesFutureCanceller
  def initialize(series, from:, reason:, actor: nil, notify_participants: false)
    @series = series
    @from = from
    @reason = reason
    @actor = actor
    @notify_participants = notify_participants
  end

  def call
    return empty_result("A start date is required") if from.blank?

    ids = series.training_sessions
                .where(status: %w[draft scheduled])
                .where("starts_at >= ?", boundary)
                .pluck(:id)
    return empty_result if ids.empty?

    TrainingSeriesCanceller.new(
      series,
      session_ids: ids,
      reason: reason,
      actor: actor,
      notify_participants: notify_participants
    ).call
  end

  private

  attr_reader :series, :from, :reason, :actor, :notify_participants

  def boundary
    series.time_zone_object.parse(from.iso8601)
  end

  def empty_result(error = nil)
    TrainingSeriesCanceller::Result.new(
      affected: [], skipped: [], errors: error ? [ error ] : []
    )
  end
end
