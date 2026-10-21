# Ends a series' recurrence without touching the sessions it already produced.
#
# This is deliberately separate from cancellation: stopping says "generate no
# more", while the existing schedule stays exactly as participants see it.
class TrainingSeriesStopper
  Result = Struct.new(:series, :changed, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(series, reason: nil, actor: nil)
    @series = series
    @reason = reason.to_s.strip.presence
    @actor = actor
  end

  def call
    return Result.new(series: series, changed: false, errors: []) if series.stopped?

    series.update!(
      status: "stopped",
      stopped_at: Time.current,
      stopped_reason: reason
    )
    Result.new(series: series, changed: true, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(series: series, changed: false, errors: e.record.errors.full_messages)
  end

  private

  attr_reader :series, :reason, :actor
end
