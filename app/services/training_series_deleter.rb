# Deletes explicitly selected occurrences that are safe to remove.
#
# Cancellation keeps history; deletion is only for drafts that never acquired
# participants or assessments. The service reports every skipped id with a
# reason instead of failing the whole request, and is atomic for the rows it
# does delete.
class TrainingSeriesDeleter
  Result = Struct.new(:deleted_ids, :skipped, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(series, session_ids:)
    @series = series
    @session_ids = Array(session_ids).map(&:to_i).select(&:positive?).uniq
  end

  def call
    return Result.new(deleted_ids: [], skipped: [], errors: [ "Select at least one occurrence" ]) if session_ids.empty?

    deleted_ids = []
    skipped = []

    ActiveRecord::Base.transaction do
      sessions = series.training_sessions
                       .includes(:training_session_participants, :assessments)
                       .where(id: session_ids)
                       .to_a
      found_ids = sessions.map(&:id)
      (session_ids - found_ids).each do |id|
        skipped << { id: id, reason: "not_in_series" }
      end

      sessions.each do |session|
        unless session.draft?
          skipped << { id: session.id, reason: "not_a_draft" }
          next
        end
        unless session.deletable_occurrence?
          skipped << { id: session.id, reason: "has_participants_or_assessments" }
          next
        end

        session.destroy!
        deleted_ids << session.id
      end
    end

    Result.new(deleted_ids: deleted_ids, skipped: skipped, errors: [])
  rescue ActiveRecord::RecordNotDestroyed => e
    Result.new(deleted_ids: [], skipped: [], errors: [ e.message ])
  end

  private

  attr_reader :series, :session_ids
end
