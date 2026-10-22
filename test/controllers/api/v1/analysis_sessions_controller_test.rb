require "test_helper"

class Api::V1::AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach_user = users(:six)
    @coach_profile = coach_profiles(:maria_coach)
    @player_user = users(:one)
    @analysis = analyses(:coach_led_draft)
  end

  def json
    JSON.parse(response.body)
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def patch_json(path, payload)
    patch path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  test "index returns analyses scoped to current user" do
    sign_in_as(@coach_user)
    get "/api/v1/analyses"

    assert_response :success
    assert json["data"].is_a?(Array)
    assert json["data"].any? { |a| a["id"] == @analysis.id }
  end

  test "index filters by status" do
    sign_in_as(@coach_user)
    get "/api/v1/analyses", params: { status: "published" }

    assert_response :success
    assert json["data"].all? { |a| a["status"] == "published" }
  end

  test "show returns analysis detail for creator" do
    sign_in_as(@coach_user)
    get "/api/v1/analyses/#{@analysis.id}"

    assert_response :success
    assert_equal @analysis.id, json["analysis"]["id"]
    assert_equal @analysis.title, json["analysis"]["title"]
    assert json["analysis"]["can_manage"]
  end

  test "show returns 404 for unauthorized user" do
    sign_in_as(@player_user)
    get "/api/v1/analyses/#{@analysis.id}"

    assert_response :not_found
  end

  test "create creates a new analysis" do
    sign_in_as(@coach_user)
    assert_difference "Analysis.count", 1 do
      post_json "/api/v1/analyses", analysis: {
        title: "New Analysis",
        summary: "A new analysis for testing",
        player_profile_ids: [ player_profiles(:john_player).id ]
      }
    end

    assert_response :created
    assert_equal "New Analysis", json["analysis"]["title"]
    assert_equal "draft", json["analysis"]["status"]
    assert json["analysis"]["can_manage"]
  end

  test "create requires authentication" do
    post_json "/api/v1/analyses", analysis: { title: "Test", summary: "Test" }
    assert_response :unauthorized
  end

  test "update allows creator to modify" do
    sign_in_as(@coach_user)
    patch_json "/api/v1/analyses/#{@analysis.id}", analysis: {
      title: "Updated Title",
      summary: "Updated summary"
    }

    assert_response :success
    assert_equal "Updated Title", json["analysis"]["title"]
    assert_equal "Updated summary", json["analysis"]["summary"]
  end

  test "update rejects non-creator" do
    sign_in_as(@player_user)
    patch_json "/api/v1/analyses/#{@analysis.id}", analysis: { title: "Hacked" }
    assert_response :forbidden
  end

  test "publish transitions draft to published" do
    sign_in_as(@coach_user)
    analysis = analyses(:coach_led_draft)
    video = Video.find_or_create_from_url!("https://youtube.com/watch?v=test123", title: "Test Video")
    analysis.analysis_videos.create!(source_type: "external", video: video, title: "Test Video")
    # john_player is already a participant via fixture (john_in_coach_led)

    post_json "/api/v1/analyses/#{analysis.id}/publish", {}
    assert_response :success
    assert_equal "published", json["analysis"]["status"]
    assert_not_nil json["analysis"]["published_at"]
  end

  test "publish fails without videos or participants" do
    sign_in_as(@coach_user)
    clean = Analysis.create!(title: "Clean Draft", summary: "No videos yet", created_by: @coach_user)

    post_json "/api/v1/analyses/#{clean.id}/publish", {}
    assert_response :unprocessable_entity
  end

  test "archive transitions draft to archived" do
    sign_in_as(@coach_user)
    post_json "/api/v1/analyses/#{@analysis.id}/archive", {}
    assert_response :success
    assert_equal "archived", json["analysis"]["status"]
    assert_not_nil json["analysis"]["archived_at"]
  end

  test "destroy only allows draft deletion by creator" do
    sign_in_as(@coach_user)
    assert_difference "Analysis.count", -1 do
      delete "/api/v1/analyses/#{@analysis.id}"
    end
    assert_response :no_content
  end

  test "destroy rejects published analysis deletion by non-admin" do
    sign_in_as(@coach_user)
    published = analyses(:published_analysis)
    delete "/api/v1/analyses/#{published.id}"
    assert_response :forbidden
  end

  test "link_assessment_session creates join record" do
    sign_in_as(@coach_user)
    post_json "/api/v1/analyses/#{@analysis.id}/link_assessment_session", assessment_session_id: assessment_sessions(:draft_squad).id

    assert_response :success
    assert json["analysis"]["assessment_sessions"].any? { |s| s["id"] == assessment_sessions(:draft_squad).id }
  end

  test "unlink_assessment_session removes join record" do
    sign_in_as(@coach_user)
    # First link
    post_json "/api/v1/analyses/#{@analysis.id}/link_assessment_session", assessment_session_id: assessment_sessions(:draft_squad).id
    assert_response :success

    # Then unlink
    delete "/api/v1/analyses/#{@analysis.id}/assessment_sessions/#{assessment_sessions(:draft_squad).id}"
    assert_response :success

    assert json["analysis"]["assessment_sessions"].empty?
  end

  test "player can view published analysis they participate in" do
    sign_in_as(users(:five))
    published = analyses(:published_analysis)

    get "/api/v1/analyses/#{published.id}"
    assert_response :success
    assert_equal published.id, json["analysis"]["id"]
  end

  test "player cannot view draft analysis they do not participate in" do
    sign_in_as(@player_user)
    get "/api/v1/analyses/#{@analysis.id}"
    assert_response :not_found
  end
end