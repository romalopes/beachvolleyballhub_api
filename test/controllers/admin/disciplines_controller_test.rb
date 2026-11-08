require "test_helper"

class Admin::DisciplinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)   # coach + admin
    @player = users(:one)  # player role only
  end

  test "admin can list disciplines" do
    sign_in_as(@admin)
    get "/admin/disciplines"
    assert_response :success
    assert_select "h1", "Disciplines"
  end

  test "admin can view discipline" do
    sign_in_as(@admin)
    get "/admin/disciplines/#{disciplines(:one).id}"
    assert_response :success
    assert_select "h2", "MyString"
  end

  test "admin can create a discipline" do
    sign_in_as(@admin)
    post "/admin/disciplines", params: { discipline: { name: "New Discipline" } }
    assert_redirected_to admin_discipline_path(Discipline.find_by(name: "New Discipline"))
    assert_equal "New Discipline", Discipline.find_by(name: "New Discipline").name
  end

  test "admin can update a discipline" do
    sign_in_as(@admin)
    patch "/admin/disciplines/#{disciplines(:one).id}", params: { discipline: { name: "Updated" } }
    assert_redirected_to admin_discipline_path(disciplines(:one).reload)
    assert_equal "Updated", disciplines(:one).reload.name
  end

  test "admin cannot delete a discipline with skills" do
    sign_in_as(@admin)
    delete "/admin/disciplines/#{disciplines(:one).id}"
    assert_redirected_to admin_disciplines_path
    assert Discipline.exists?(disciplines(:one).id)
  end

  test "non-admin is redirected from disciplines index" do
    sign_in_as(@player)
    get "/admin/disciplines"
    assert_redirected_to root_path
  end

  test "admin disciplines index shows total count" do
    sign_in_as(@admin)
    get "/admin/disciplines"
    assert_response :success
    assert_includes response.body, "#{Discipline.count} discipline"
  end

  test "admin disciplines index links skill counts to filtered skills" do
    sign_in_as(@admin)
    get "/admin/disciplines"
    assert_response :success
    assert_select "a[href=?]", admin_skills_path(discipline_id: disciplines(:one).id)
  end
end
