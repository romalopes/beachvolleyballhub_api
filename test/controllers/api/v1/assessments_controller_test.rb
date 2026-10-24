require "test_helper"

class Api::V1::AssessmentsControllerTest < ActionDispatch::IntegrationTest
  test "index exposes the selected definition and linked account player identity" do
    user = users(:six)
    profile = player_profiles(:john_player)
    profile.update!(display_name: "Coogee 2")
    coach = coach_profiles(:maria_coach)
    coach.update!(display_name: "Coach profile")
    session = assessment_sessions(:draft_squad)
    assessment = Assessment.create!(
      player_profile: profile,
      coach_profile: coach,
      created_by: user,
      assessment_definition: assessment_definitions(:balanced),
      assessment_session: session,
      status: "draft"
    )
    sign_in_as(user)

    get "/api/v1/assessments", params: { status: "draft" }

    assert_response :success
    row = JSON.parse(response.body).fetch("data").find { |item| item.fetch("id") == assessment.id }
    assert_equal assessment_definitions(:balanced).id, row.fetch("assessment_definition_id")
    assert_equal "A-Level Assessment", row.dig("assessment_definition", "name")
    assert_equal profile.id, row.dig("player_profile", "id")
    assert_equal "Coogee 2", row.dig("player_profile", "display_name")
    assert_equal "John Smith", row.dig("player_profile", "account_name")
    assert_equal coach.id, row.dig("coach_profile", "id")
    assert_equal "Coach profile", row.dig("coach_profile", "display_name")
    assert_equal "Maria Silva", row.dig("coach_profile", "account_name")
    assert_equal "Coach profile", row.fetch("coach_name")
    assert_equal "Maria Silva", row.fetch("coach_account_name")
    assert_equal user.name, row.dig("created_by", "name")
    assert_equal session.id, row.fetch("assessment_session_id")
    assert_equal "Tuesday squad screening", row.dig("assessment_session", "name")
    assert_equal session.scheduled_on.iso8601, row.dig("assessment_session", "scheduled_on")
    assert_equal "Tuesday squad screening", row.fetch("assessment_session_name")
    assert_equal session.scheduled_on.iso8601, row.fetch("assessment_session_scheduled_on")
  end

  test "index returns a nil account name for an accountless player profile" do
    user = users(:six)
    assessment = assessments(:draft_ready)
    sign_in_as(user)

    get "/api/v1/assessments", params: { status: "draft" }

    assert_response :success
    row = JSON.parse(response.body).fetch("data").find { |item| item.fetch("id") == assessment.id }
    assert_equal "Pedro Santos", row.dig("player_profile", "display_name")
    assert_nil row.dig("player_profile", "account_name")
    assert_nil row.fetch("assessment_session")
    assert_nil row.fetch("assessment_session_name")
    assert_nil row.fetch("assessment_session_scheduled_on")
  end

  test "index exposes an accountless coach profile name without an account name" do
    user = users(:six)
    coach = coach_profiles(:unclaimed_roster_coach)
    assessment = Assessment.create!(
      player_profile: player_profiles(:pedro_player),
      coach_profile: coach,
      created_by: user,
      category: categories(:assessment_rubric),
      status: "draft"
    )
    sign_in_as(user)

    get "/api/v1/assessments", params: { status: "draft" }

    assert_response :success
    row = JSON.parse(response.body).fetch("data").find { |item| item.fetch("id") == assessment.id }
    assert_equal "Roster Coach", row.fetch("coach_name")
    assert_nil row.fetch("coach_account_name")
  end
end