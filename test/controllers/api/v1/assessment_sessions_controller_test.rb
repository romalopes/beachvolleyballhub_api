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

  def json_headers
    { "Accept" => "application/json", "Content-Type" => "application/json" }
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: json_headers.merge("Authorization" => "Bearer #{@token}")
  end

  def patch_json(path, payload)
    patch path, params: payload.to_json, headers: json_headers.merge("Authorization" => "Bearer #{@token}")
  end

  def put_json(path, payload)
    put path, params: payload.to_json, headers: json_headers.merge("Authorization" => "Bearer #{@token}")
  end

  def get_json(path, headers = {})
    get path, headers: { "Accept" => "application/json" }.merge(headers)
    JSON.parse(response.body)
  end

  def auth_header(token = @token)
    { "Authorization" => "Bearer #{token}" }
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
    @token = Current.session.api_token
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
    @token = Current.session.api_token
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
    @token = Current.session.api_token
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

  # --- New endpoint tests ---

  test "show_by_slug returns session for authorized user" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "internal")

    get_json "/api/v1/assessment_sessions/#{session.public_slug}", auth_header

    assert_response :success
    assert_equal session.id, json.dig("assessment_session", "id")
    assert_equal session.public_slug, json.dig("assessment_session", "public_slug")
    assert_equal "internal", json.dig("assessment_session", "visibility")
  end

  test "show_by_slug returns 403 for unauthorized user" do
    other_user = users(:three)
    sign_in_as(other_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "internal")

    get_json "/api/v1/assessment_sessions/#{session.public_slug}", auth_header

    assert_response :forbidden
  end

  test "show_by_slug returns 404 for unknown slug" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token

    get_json "/api/v1/assessment_sessions/unknown-slug-xyz", auth_header

    assert_response :not_found
  end

  test "show_by_share_token returns session for valid unlisted token without auth" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    raw_token = session.regenerate_share_token!
    session.save!

    get "/api/v1/assessment_sessions/share/#{raw_token}"

    assert_response :success
    assert_equal session.id, json.dig("assessment_session", "id")
    assert_equal "unlisted", json.dig("assessment_session", "visibility")

    # Restricted payload - no notes, no coach account_name, no ranking, no consolidations
    assert_nil json.dig("assessment_session", "notes")
    assert_nil json.dig("assessment_session", "coach_profile", "account_name")
    assert_nil json.dig("assessment_session", "ranking")
    assert_nil json.dig("assessment_session", "consolidations")

    # Cache-Control header
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "show_by_share_token returns 404 for invalid token" do
    get "/api/v1/assessment_sessions/share/invalid-token-123"

    assert_response :not_found
    assert_equal "Not found", json["error"]
  end

  test "show_by_share_token returns 404 for revoked token (session no longer unlisted)" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    raw_token = session.regenerate_share_token!
    session.save!

    # Change visibility away from unlisted - token should be invalidated
    session.update!(visibility: "internal")

    get "/api/v1/assessment_sessions/share/#{raw_token}"

    assert_response :not_found
  end

  test "show_by_share_token returns 404 for token of non-unlisted session" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "public")
    raw_token = session.regenerate_share_token!
    session.save!

    get "/api/v1/assessment_sessions/share/#{raw_token}"

    assert_response :not_found
  end

  test "regenerate_share_link returns share_url for management user on unlisted session" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")

    post_json "/api/v1/assessment_sessions/#{session.public_slug}/regenerate_share_link", {}

    assert_response :success
    assert json["share_url"].present?
    assert json["share_url"].start_with?("http")

    # Token should be new and valid
    new_token = json["share_url"].split("/").last
    get "/api/v1/assessment_sessions/share/#{new_token}"
    assert_response :success
  end

  test "regenerate_share_link invalidates old token" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")

    post_json "/api/v1/assessment_sessions/#{session.public_slug}/regenerate_share_link", {}
    assert_response :success
    first_token = json["share_url"].split("/").last

    post_json "/api/v1/assessment_sessions/#{session.public_slug}/regenerate_share_link", {}
    assert_response :success
    second_token = json["share_url"].split("/").last

    assert_not_equal first_token, second_token

    # First token should be invalid
    get "/api/v1/assessment_sessions/share/#{first_token}"
    assert_response :not_found

    # Second token should work
    get "/api/v1/assessment_sessions/share/#{second_token}"
    assert_response :success
  end

  test "regenerate_share_link returns 403 for non-management user" do
    other_user = users(:three)
    sign_in_as(other_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")

    post_json "/api/v1/assessment_sessions/#{session.public_slug}/regenerate_share_link", {}

    assert_response :forbidden
  end

  test "regenerate_share_link returns 403 for unassigned coach" do
    unassigned_coach = users(:one) # player user
    sign_in_as(unassigned_coach)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")

    post_json "/api/v1/assessment_sessions/#{session.public_slug}/regenerate_share_link", {}

    assert_response :forbidden
  end

  test "regenerate_share_link returns 422 for non-unlisted session" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "internal")

    post_json "/api/v1/assessment_sessions/#{session.public_slug}/regenerate_share_link", {}

    assert_response :unprocessable_entity
  end

  test "update visibility via PATCH /api/v1/assessment_sessions/:id" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "internal")

    patch "/api/v1/assessment_sessions/#{session.id}",
          params: { assessment_session: { visibility: "public" } }.to_json,
          headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}" }

    assert_response :success
    assert_equal "public", json.dig("assessment_session", "visibility")
    assert json.dig("assessment_session", "public_slug").present?
  end

  test "update visibility to invalid value returns 422" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)

    patch "/api/v1/assessment_sessions/#{session.id}",
          params: { assessment_session: { visibility: "invalid" } }.to_json,
          headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}" }

    assert_response :unprocessable_entity
    assert json["errors"].any?
  end

  test "visibility change from unlisted to internal clears share token" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    raw_token = session.regenerate_share_token!
    session.save!

    # Verify token works before change
    get "/api/v1/assessment_sessions/share/#{raw_token}"
    assert_response :success

    # Change visibility
    patch "/api/v1/assessment_sessions/#{session.id}",
          params: { assessment_session: { visibility: "internal" } }.to_json,
          headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}" }

    assert_response :success

    # Token should now be invalid
    get "/api/v1/assessment_sessions/share/#{raw_token}"
    assert_response :not_found
  end

  # --- Nested resource protection tests ---

  test "add_players requires management authorization" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    # Create a new player profile not in the session
    new_player = PlayerProfile.create!(
      display_name: "Test New Player",
      preferred_position: "blocker",
      level: "intermediate",
      status: "active"
    )

    post_json "/api/v1/assessment_sessions/#{session.id}/add_players", { players: [{ player_profile_id: new_player.id, inclusion: "included" }] }

    assert_response :created
    assert json.dig("assessment_session", "participants").size >= 1
  end

  test "add_players forbidden for non-management user" do
    other_user = users(:three) # not the coach of record
    sign_in_as(other_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)

    post_json "/api/v1/assessment_sessions/#{session.id}/add_players", { players: [{ player_profile_id: player_profiles(:john_player).id, inclusion: "included" }] }

    assert_response :forbidden
  end

  test "add_players forbidden for unlisted session via share token (no auth)" do
    session = assessment_sessions(:draft_squad)
    session.update!(visibility: "unlisted")
    raw_token = session.regenerate_share_token!
    session.save!

    # Try to add players via share token endpoint (which doesn't exist for add_players)
    post_json "/api/v1/assessment_sessions/#{session.id}/add_players", { players: [{ player_profile_id: player_profiles(:john_player).id, inclusion: "included" }] }

    # Should fail because no auth token
    assert_response :unauthorized
  end

  test "remove_players requires management authorization" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    participant = session.participants.first

    patch_json "/api/v1/assessment_sessions/#{session.id}/remove_players", { player_profile_ids: [participant.player_profile_id] }

    assert_response :success
    assert_equal 1, json["removed"]
  end

  test "remove_players forbidden for non-management user" do
    other_user = users(:three)
    sign_in_as(other_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)

    patch_json "/api/v1/assessment_sessions/#{session.id}/remove_players", { player_profile_ids: [session.participants.first.player_profile_id] }

    assert_response :forbidden
  end

  test "scores requires management authorization" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    player = session.participants.included.first.player_profile
    categories = session.assessment_definition.assessment_categories

    # Supply scores for all categories in the definition - correct format for score grid
    score_rows = [{
      player_profile_id: player.id,
      scores: categories.map do |cat|
        { assessment_category_id: cat.id, scale: "one_to_ten", reported_value: 8 }
      end
    }]

    put_json "/api/v1/assessment_sessions/#{session.id}/scores", { scores: score_rows }

    assert_response :success
  end

  test "scores forbidden for non-management user" do
    other_user = users(:three)
    sign_in_as(other_user)
    @token = Current.session.api_token
    session = assessment_sessions(:draft_squad)
    player = session.participants.first.player_profile
    categories = session.assessment_definition.assessment_categories

    score_rows = [{
      player_profile_id: player.id,
      scores: categories.map do |cat|
        { assessment_category_id: cat.id, scale: "one_to_ten", reported_value: 8 }
      end
    }]

    put_json "/api/v1/assessment_sessions/#{session.id}/scores", { scores: score_rows }

    assert_response :forbidden
  end

  test "ranking endpoint requires authorization" do
    sign_in_as(@coach_user)
    @token = Current.session.api_token
    session = assessment_sessions(:published_squad)
    session.update!(visibility: "internal")

    get "/api/v1/assessment_sessions/#{session.id}/ranking", headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :success
    # Ranking endpoint returns structure with ranking, incomplete, excluded
    assert json["ranking"].is_a?(Array)
    assert json["incomplete"].is_a?(Array)
    assert json["excluded"].is_a?(Array)
  end

  test "ranking endpoint forbidden for non-authorized user" do
    other_user = users(:three)
    sign_in_as(other_user)
    @token = Current.session.api_token
    session = assessment_sessions(:published_squad)
    session.update!(visibility: "internal")

    get "/api/v1/assessment_sessions/#{session.id}/ranking", headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :forbidden
  end

  test "ranking endpoint accessible for public session" do
    sign_in_as(users(:five)) # player user
    @token = Current.session.api_token
    session = assessment_sessions(:published_squad)
    session.update!(visibility: "public")

    get "/api/v1/assessment_sessions/#{session.id}/ranking", headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :success
    # Ranking endpoint returns structure with ranking, incomplete, excluded
    assert json["ranking"].is_a?(Array)
    assert json["incomplete"].is_a?(Array)
    assert json["excluded"].is_a?(Array)
  end
end
