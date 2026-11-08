require "test_helper"

class Api::V1::DisciplinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)    # coach + admin
    @coach = users(:three)  # coach role only
  end

  test "index is public" do
    get "/api/v1/disciplines"
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert body.any? { |c| c["slug"] == "mystring-one" }
  end

  test "show is public" do
    get "/api/v1/disciplines/mystring-one"
    assert_response :success
    assert_equal "mystring-one", JSON.parse(response.body)["slug"]
  end

  test "show falls back to lookup by id" do
    discipline = disciplines(:one)
    get "/api/v1/disciplines/#{discipline.id}"
    assert_response :success
    assert_equal discipline.id, JSON.parse(response.body)["id"]
  end

  test "guest cannot create a discipline" do
    assert_no_difference("Discipline.count") do
      post "/api/v1/disciplines", params: { discipline: { name: "Brand New" } }
    end
    assert_response :unauthorized
  end

  test "non-admin coach cannot create a discipline" do
    sign_in_as(@coach)
    assert_no_difference("Discipline.count") do
      post "/api/v1/disciplines", params: { discipline: { name: "Brand New" } }
    end
    assert_response :forbidden
  end

  test "admin can create a discipline" do
    sign_in_as(@admin)
    assert_difference("Discipline.count") do
      post "/api/v1/disciplines", params: { discipline: { name: "Brand New" } }
    end
    assert_response :created
    assert_equal "brand-new", Discipline.find_by(name: "Brand New").slug
  end

  test "create returns 422 on validation errors" do
    sign_in_as(@admin)
    post "/api/v1/disciplines", params: { discipline: { name: "" } }
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "admin can rename the discipline" do
    discipline = disciplines(:one)
    sign_in_as(@admin)
    patch "/api/v1/disciplines/#{discipline.slug}", params: { discipline: { name: "Renamed Discipline" } }
    assert_response :success
    assert_equal "Renamed Discipline", discipline.reload.name
  end

  test "update returns 422 on validation errors" do
    discipline = disciplines(:one)
    sign_in_as(@admin)
    patch "/api/v1/disciplines/#{discipline.slug}", params: { discipline: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "admin can delete the discipline" do
    discipline = Discipline.create!(name: "Disposable")
    sign_in_as(@admin)
    assert_difference("Discipline.count", -1) do
      delete "/api/v1/disciplines/#{discipline.slug}"
    end
    assert_response :no_content
  end

  test "destroy cascades to its skills" do
    discipline = Discipline.create!(name: "With Skills")
    Skill.create!(title: "Child", discipline: discipline)
    sign_in_as(@admin)
    assert_difference("Discipline.count", -1) do
      assert_difference("Skill.count", -1) do
        delete "/api/v1/disciplines/#{discipline.slug}"
      end
    end
    assert_response :no_content
  end
end
