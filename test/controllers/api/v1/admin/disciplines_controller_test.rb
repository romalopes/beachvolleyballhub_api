require "test_helper"

class Api::V1::Admin::DisciplinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)   # coach + admin
    @coach = users(:three) # coach role only
    @player = users(:one)  # player role only
  end

  test "admin can list disciplines" do
    sign_in_as(@admin)
    get "/api/v1/admin/disciplines"
    assert_response :success
    body = JSON.parse(response.body)
    assert body.any? { |c| c["name"] == "MyString" }
  end

  test "admin can show a discipline" do
    sign_in_as(@admin)
    get "/api/v1/admin/disciplines/#{disciplines(:one).id}"
    assert_response :success
    assert_equal "MyString", JSON.parse(response.body)["name"]
  end

  test "admin can create a discipline" do
    sign_in_as(@admin)
    post "/api/v1/admin/disciplines", params: { discipline: { name: "New Discipline" } }
    assert_response :created
    assert_equal "New Discipline", Discipline.find_by(name: "New Discipline").name
  end

  test "admin can update a discipline" do
    discipline = disciplines(:one)
    sign_in_as(@admin)
    patch "/api/v1/admin/disciplines/#{discipline.id}", params: { discipline: { name: "Updated" } }
    assert_response :success
    assert_equal "Updated", discipline.reload.name
  end

  test "admin can delete a discipline without skills" do
    discipline = Discipline.create!(name: "Empty Discipline")
    sign_in_as(@admin)
    delete "/api/v1/admin/disciplines/#{discipline.id}"
    assert_response :no_content
    assert_not Discipline.exists?(discipline.id)
  end

  test "admin cannot delete a discipline with skills" do
    discipline = disciplines(:one) # skills(:one) belongs to it
    sign_in_as(@admin)
    delete "/api/v1/admin/disciplines/#{discipline.id}"
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/contains 1 skill/, body["error"])
    assert Discipline.exists?(discipline.id)
  end

  test "validation errors return 422" do
    sign_in_as(@admin)
    post "/api/v1/admin/disciplines", params: { discipline: { name: "" } }
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "coach cannot access admin disciplines" do
    sign_in_as(@coach)
    get "/api/v1/admin/disciplines"
    assert_response :forbidden
  end

  test "player cannot access admin disciplines" do
    sign_in_as(@player)
    get "/api/v1/admin/disciplines"
    assert_response :forbidden
  end

  test "unauthenticated cannot access admin disciplines" do
    get "/api/v1/admin/disciplines"
    assert_response :unauthorized
  end
end
