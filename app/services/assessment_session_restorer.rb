# Restores a withdrawn assessment session, which only an admin may do.
#
# `to_status` is explicit rather than a boolean, because the two destinations are
# genuinely different operations and the caller has to choose deliberately:
#
#   "draft"     — puts the session back in progress, and its published
#                 results back to draft with it (the inverse of the publisher).
#                 The coach rescores it and publishes again on their own terms.
#   "published" — republishes it. This is NOT a status write: it runs the
#                 publisher so the session's assessments are re-activated. A
#                 plain `update!` would leave a published session whose results
#                 are still drafts, and any ranking built on it would score
#                 nothing at all.
#
# Refusals raise with 422 semantics. Republishing goes through
# `AssessmentSessionPublisher`, so it is refused exactly as a first publication
# would be — most importantly, a session with unscored players cannot be
# published, and a restored-but-unscored session is exactly the trap.
class AssessmentSessionRestorer
  class Error < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = Array(errors)
      super(@errors.join(", "))
    end
  end

  DESTINATIONS = %w[draft published].freeze

  def initialize(session, to_status:)
    @session = session
    @to_status = to_status
  end

  def call
    raise Error, "Only a withdrawn session can be restored" unless @session.withdrawn?
    raise Error, "Unknown destination #{@to_status}" unless DESTINATIONS.include?(@to_status)

    return restore_to_draft unless @to_status == "published"

    republish
  end

  private

  def restore_to_draft
    AssessmentSession.transaction do
      @session.update!(status: "draft", published_at: nil)
      # Returning the session to draft returns its results to draft too - the
      # inverse of the publisher, which is what activates drafts on publish. A
      # session that is back in progress cannot keep endorsing its numbers as
      # club knowledge, so every non-draft row (active, or individually
      # withdrawn by its author) goes back to draft; republishing re-activates
      # them from there.
      @session.assessments.where.not(status: "draft").find_each do |assessment|
        assessment.update!(status: "draft")
      end
    end
    @session
  end

  # Delegating to the publisher is what makes this safe: the draft-to-published
  # transition already knows how to refuse a session that is not ready, and
  # reusing it means a restore can never be more permissive than a first
  # publication. The full return-to-draft (session AND results) happens first
  # because the publisher only ever accepts a draft. If the publisher refuses,
  # nothing needs rolling back: the session and its results are already in a
  # coherent draft state, which is where a withdrawn session that was not ready
  # to come back belongs - the admin fixes the scores there.
  def republish
    restore_to_draft
    AssessmentSessionPublisher.new(@session).call
  end
end
