require "test_helper"

class Api::V1::AssessmentSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach_user = users(:six)
    @coach_profile = coach_profiles(:maria_coach)
    @definition = assessment_definitions(:balanced)
  end

  def json
    JSON.parse(response.body)
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def create_draft_session
    post_json "/api/v1/assessment_sessions", assessment_session: {
      name: "Inline roster test",
      assessment_definition_id: @definition.id,
      coach_profile_id: @coach_profile.id,
      scheduled_on: Date.current.iso8601
    }

    assert_response :created
    json.dig("assessment_session", "id")
  end

  test "add_players creates an accountless player from an inline profile" do
    sign_in_as(@coach_user)
    session_id = create_draft_session

    assert_difference([ "PlayerProfile.count", "AssessmentSessionParticipant.count" ], 1) do
      post_json "/api/v1/assessment_sessions/#{session_id}/add_players", players: [ {
        profile: {
          display_name: "Test TESt",
          email: "inline.player@example.com"
        },
        inclusion: "included"
      } ]
    end

    assert_response :created
    participant = json.dig("assessment_session", "participants").sole
    profile = PlayerProfile.find(participant.fetch("player_profile_id"))

    assert_equal "Test TESt", profile.display_name
    assert_equal "inline.player@example.com", profile.email
    assert_nil profile.account_id
    assert_equal "Test TESt", participant.fetch("player_name")
    assert_equal "included", participant.fetch("inclusion")
    assert_nil participant.fetch("account_name")
  end

  test "participants expose the linked account name" do
    sign_in_as(@coach_user)
    session_id = create_draft_session

    post_json "/api/v1/assessment_sessions/#{session_id}/add_players", players: [ {
      player_profile_id: player_profiles(:john_player).id,
      inclusion: "included"
    } ]
    assert_response :created

    participant = json.dig("assessment_session", "participants").sole
    assert_equal "John Smith", participant.fetch("account_name")
    assert_equal "John Smith", participant.fetch("player_name")
  end

  test "account_name differs from the profile display name when staff renamed the profile" do
    sign_in_as(@coach_user)
    session_id = create_draft_session

    profile = PlayerProfile.create!(
      account: accounts(:one),
      display_name: "Coogee 2",
      status: "active",
      visibility: "shared"
    )

    post_json "/api/v1/assessment_sessions/#{session_id}/add_players", players: [ {
      player_profile_id: profile.id,
      inclusion: "included"
    } ]
    assert_response :created

    participant = json.dig("assessment_session", "participants").sole
    assert_equal "John Smith", participant.fetch("account_name")
    assert_equal "Coogee 2", participant.fetch("player_name")
  end
end