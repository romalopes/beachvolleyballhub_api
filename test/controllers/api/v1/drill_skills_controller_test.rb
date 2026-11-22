require "test_helper"

class Api::V1::DrillSkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @drill = drills(:one)
    @skill = skills(:two)
    @admin = users(:two)     # coach + admin
    @player = users(:one)    # player only (no content authority)
    @admin_headers = sign_in_with_api_token(@admin).last
    @player_headers = sign_in_with_api_token(@player).last
  end

  # --- public reads (SPA API-health check hits this anonymously) ---------------

  test "index lists drill/skill links with associations anonymously" do
    DrillSkill.create!(drill: @drill, skill: skills(:one))
    get "/api/v1/drill_skills"
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert body.first.key?("drill")
    assert body.first.key?("skill")
  end

  test "show returns the link with associations anonymously" do
    link = DrillSkill.create!(drill: @drill, skill: skills(:one))
    get "/api/v1/drill_skills/#{link.id}"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @drill.id, body["drill"]["id"]
  end

  test "show returns 404 for an unknown id" do
    get "/api/v1/drill_skills/0"
    assert_response :not_found
    assert_equal "DrillSkill not found", JSON.parse(response.body)["error"]
  end

  # --- SEC-01: writes are no longer anonymous ---------------------------------

  test "anonymous create is rejected and persists nothing" do
    assert_no_difference("DrillSkill.count") do
      post "/api/v1/drill_skills", params: { drill_skill: { drill_id: @drill.id, skill_id: @skill.id } }
    end
    assert_response :unauthorized
  end

  test "anonymous update is rejected" do
    link = DrillSkill.create!(drill: @drill, skill: skills(:one))
    patch "/api/v1/drill_skills/#{link.id}", params: { drill_skill: { skill_id: @skill.id } }
    assert_response :unauthorized
    assert_equal skills(:one).id, link.reload.skill_id
  end

  test "anonymous destroy is rejected and deletes nothing" do
    link = DrillSkill.create!(drill: @drill, skill: @skill)
    assert_no_difference("DrillSkill.count") do
      delete "/api/v1/drill_skills/#{link.id}"
    end
    assert_response :unauthorized
  end

  test "authenticated user without content authority cannot create" do
    assert_no_difference("DrillSkill.count") do
      post "/api/v1/drill_skills",
           params: { drill_skill: { drill_id: @drill.id, skill_id: @skill.id } },
           headers: @player_headers
    end
    assert_response :forbidden
  end

  # --- authorized writes (admin) ---------------------------------------------

  test "admin create links a skill to a drill" do
    assert_difference("DrillSkill.count") do
      post "/api/v1/drill_skills",
           params: { drill_skill: { drill_id: @drill.id, skill_id: @skill.id } }.to_json,
           headers: @admin_headers
    end
    assert_response :created
    assert_includes @drill.reload.skills.map(&:id), @skill.id
  end

  test "admin create returns 422 when params are missing" do
    post "/api/v1/drill_skills",
         params: { drill_skill: { drill_id: @drill.id } }.to_json,
         headers: @admin_headers
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "admin update moves the link to another skill" do
    link = DrillSkill.create!(drill: @drill, skill: skills(:one))
    patch "/api/v1/drill_skills/#{link.id}",
          params: { drill_skill: { skill_id: @skill.id } }.to_json,
          headers: @admin_headers
    assert_response :success
    assert_equal @skill.id, link.reload.skill_id
  end

  test "admin destroy removes the link but keeps drill and skill" do
    link = DrillSkill.create!(drill: @drill, skill: @skill)
    assert_difference("DrillSkill.count", -1) do
      delete "/api/v1/drill_skills/#{link.id}", headers: @admin_headers
    end
    assert_response :no_content
    assert Drill.exists?(@drill.id)
    assert Skill.exists?(@skill.id)
  end
end
