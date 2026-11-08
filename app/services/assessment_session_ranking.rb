# Computes an assessment session's ranking from the result rows already stored
# against it. Ranking is server-owned: clients receive the result, never submit
# it.
#
# Only complete rows are ranked. An included player with a missing discipline is
# reported in `incomplete` with the exact missing discipline ids — never as zero —
# and excluded players are reported separately so a deliberate absentee is not
# confused with an unscored player.
class AssessmentSessionRanking
  def initialize(session)
    @session = session
  end

  def call
    complete = []
    incomplete = []

    included_participants.each do |participant|
      assessment = assessment_for(participant.player_profile_id)
      missing = missing_discipline_ids(assessment)
      entry = entry_for(participant, assessment, missing)

      if complete_result?(assessment, missing)
        complete << entry.merge(status: "complete", overall_score: assessment.score)
      else
        incomplete << entry.merge(status: result_status(assessment, missing), overall_score: nil)
      end
    end

    assign_ranks!(complete.sort_by { |row| [ -row[:overall_score], row[:player_profile_id] ] })

    {
      ranking: complete,
      incomplete: incomplete,
      excluded: excluded_participants
    }
  end

  private

  attr_reader :session

  def included_participants
    session.participants.includes(player_profile: :account).included.to_a
  end

  def excluded_participants
    session.participants.includes(player_profile: :account).excluded.map do |participant|
      {
        player_profile_id: participant.player_profile_id,
        player_name: player_name(participant),
        account_name: participant.player_profile.account&.full_name.presence,
        status: "excluded",
        overall_score: nil,
        rank: nil,
        missing_discipline_ids: [],
        missing_reason: participant.missing_reason
      }
    end
  end

  def assessments_by_player
    @assessments_by_player ||=
      session.assessments
             .includes(assessment_category_scores: :assessment_category)
             .where(player_profile_id: included_participants.map(&:player_profile_id))
             .group_by(&:player_profile_id)
  end

  def assessment_for(player_profile_id)
    assessments_by_player[player_profile_id]&.max_by(&:id)
  end

  def expected_discipline_ids
    @expected_discipline_ids ||=
      session.assessment_definition.assessment_categories.order(:position, :id).pluck(:id)
  end

  # A discipline is missing when its rollup has no number. Delegating to the model
  # rather than re-reading `criterion_id.nil?` here is the point: the publish
  # gate, the weighted total and this ranking all asked "is this discipline
  # scored?" and must not be able to answer differently.
  def missing_discipline_ids(assessment)
    return expected_discipline_ids if assessment.nil?

    missing = session.assessment_definition.assessment_categories
                 .reject { |discipline| assessment.discipline_rollup(discipline).rated? }
    missing.map(&:id)
  end

  def complete_result?(assessment, missing)
    assessment.present? &&
      !assessment.withdrawn? &&
      missing.empty? &&
      assessment.score.present?
  end

  def result_status(assessment, missing)
    return "incomplete" if assessment.nil?
    return "withdrawn" if assessment.withdrawn?
    return "incomplete" if missing.any? || assessment.score.nil?

    "complete"
  end

  def entry_for(participant, assessment, missing)
    {
      player_profile_id: participant.player_profile_id,
      player_name: player_name(participant),
      # The linked account name, when the profile is claimed by an account.
      # Clients show "Account (profile)" so a display name a coach recorded
      # separately from the identity stays visible. nil for profile-only rows.
      account_name: participant.player_profile.account&.full_name.presence,
      assessment_id: assessment&.id,
      overall_score: nil,
      rank: nil,
      missing_discipline_ids: missing,
      discipline_scores: discipline_scores(assessment)
    }
  end

  # The coach's own typed entry per discipline, so a client can render the grid it
  # would have shown at entry time. The weighted total alone cannot explain how a
  # result was reached, and a published session is read-only.
  #
  # Only criterion-less rows are reported: the criteria layer is scaffolded but
  # not in use (D11), so a discipline still carries exactly one number.
  def discipline_scores(assessment)
    return [] if assessment.nil?

    assessment.assessment_category_scores
              .select { |row| row.criterion_id.nil? }
              .map do |row|
                {
                  assessment_category_id: row.assessment_category_id,
                  reported_value: row.reported_value,
                  scale: row.scale,
                  score: row.score
                }
              end
  end

  def player_name(participant)
    participant.player_profile.full_name.presence || "Player ##{participant.player_profile_id}"
  end

  # Standard competition ranking (D15): equal scores share a rank and the next
  # rank skips the tied count (`1, 2, 2, 4`). The presentation order is made
  # deterministic by player id without changing the rank itself.
  def assign_ranks!(rows)
    previous_score = nil
    previous_rank = nil

    rows.each_with_index do |row, index|
      row[:rank] = if row[:overall_score] == previous_score
                     previous_rank
      else
                     index + 1
      end
      previous_score = row[:overall_score]
      previous_rank = row[:rank]
    end

    rows
  end
end
