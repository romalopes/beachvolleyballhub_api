require "test_helper"

class AssessmentSessionRestorerTest < ActiveSupport::TestCase
  # A rated result row on a session: the shape a publication leaves behind.
  def rated_result(session, player, status)
    Assessment.create!(
      player_profile: player_profiles(player),
      coach_profile: coach_profiles(:maria_coach),
      created_by: users(:six),
      category: categories(:assessment_rubric),
      assessment_session: session,
      value: 4,
      status: status
    )
  end

  test "restoring to draft returns the session and all of its results to draft" do
    session = assessment_sessions(:published_squad)
    published_result = rated_result(session, :pedro_player, "active")
    retracted_result = rated_result(session, :john_player, "withdrawn")
    untouched_draft = Assessment.create!(
      player_profile: player_profiles(:john_player),
      coach_profile: coach_profiles(:maria_coach),
      created_by: users(:six),
      category: categories(:assessment_rubric),
      assessment_session: session,
      status: "draft"
    )
    other_result = rated_result(assessment_sessions(:draft_squad), :pedro_player, "active")

    session.update!(status: "withdrawn", published_at: nil)

    restored = AssessmentSessionRestorer.new(session, to_status: "draft").call

    assert restored.draft?
    assert_nil restored.published_at
    assert_equal "draft", published_result.reload.status
    assert_equal "draft", retracted_result.reload.status
    assert_equal "draft", untouched_draft.reload.status
    assert_equal "active", other_result.reload.status
  end

  test "only a withdrawn session can be restored" do
    error = assert_raises(AssessmentSessionRestorer::Error) do
      AssessmentSessionRestorer.new(assessment_sessions(:published_squad), to_status: "draft").call
    end

    assert_equal "Only a withdrawn session can be restored", error.message
  end

  test "a refused republish leaves the session and its results coherently in draft" do
    session = assessment_sessions(:published_squad)
    result = rated_result(session, :pedro_player, "active")
    session.update!(status: "withdrawn", published_at: nil)

    # The included participant of published_squad (john_player) has no scores,
    # so the publisher refuses the republish - and the session plus its results
    # stay in the coherent draft state the restore produced, ready to be
    # rescored.
    assert_raises(AssessmentSessionPublisher::Error) do
      AssessmentSessionRestorer.new(session, to_status: "published").call
    end

    assert_equal "draft", session.reload.status
    assert_nil session.reload.published_at
    assert_equal "draft", result.reload.status
  end
end
