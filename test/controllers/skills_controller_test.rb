require "test_helper"

# SEC-07: the legacy server-rendered Skills pages must not expose
# non-published/private skills to anonymous visitors (mirrors SkillPolicy).
class SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @discipline = disciplines(:one)
  end

  test "index lists published shared skills and hides drafts" do
    draft = Skill.create!(title: "Hidden Draft Skill", discipline: @discipline, status: "draft")

    get "/skills"
    assert_response :success
    assert_includes response.body, skills(:one).title          # published+shared
    assert_not_includes response.body, draft.title              # draft hidden
  end

  test "show returns a published shared skill" do
    get "/skills/#{skills(:one).slug}"
    assert_response :success
  end

  test "show returns 404 for a draft skill" do
    draft = Skill.create!(title: "Draft Only", slug: "draft-only-sec07", discipline: @discipline, status: "draft")

    get "/skills/#{draft.slug}"
    assert_response :not_found
  end

  test "show returns 404 for a private skill" do
    private_skill = Skill.create!(
      title: "Private Only", slug: "private-only-sec07",
      discipline: @discipline, status: "published", visibility: "private"
    )

    get "/skills/#{private_skill.slug}"
    assert_response :not_found
  end
end
