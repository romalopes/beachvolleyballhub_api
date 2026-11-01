require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)    # coach + admin
    @coach = users(:three)  # coach role only
  end

  test "index is public" do
    get "/api/v1/categories"
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert body.any? { |c| c["slug"] == "mystring-one" }
  end

  test "show is public" do
    get "/api/v1/categories/mystring-one"
    assert_response :success
    assert_equal "mystring-one", JSON.parse(response.body)["slug"]
  end

  test "show falls back to lookup by id" do
    category = categories(:one)
    get "/api/v1/categories/#{category.id}"
    assert_response :success
    assert_equal category.id, JSON.parse(response.body)["id"]
  end

  test "guest cannot create a category" do
    assert_no_difference("Category.count") do
      post "/api/v1/categories", params: { category: { name: "Brand New" } }
    end
    assert_response :unauthorized
  end

  test "non-admin coach cannot create a category" do
    sign_in_as(@coach)
    assert_no_difference("Category.count") do
      post "/api/v1/categories", params: { category: { name: "Brand New" } }
    end
    assert_response :forbidden
  end

  test "admin can create a category" do
    sign_in_as(@admin)
    assert_difference("Category.count") do
      post "/api/v1/categories", params: { category: { name: "Brand New" } }
    end
    assert_response :created
    assert_equal "brand-new", Category.find_by(name: "Brand New").slug
  end

  test "create returns 422 on validation errors" do
    sign_in_as(@admin)
    post "/api/v1/categories", params: { category: { name: "" } }
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "admin can rename the category" do
    category = categories(:one)
    sign_in_as(@admin)
    patch "/api/v1/categories/#{category.slug}", params: { category: { name: "Renamed Category" } }
    assert_response :success
    assert_equal "Renamed Category", category.reload.name
  end

  test "update returns 422 on validation errors" do
    category = categories(:one)
    sign_in_as(@admin)
    patch "/api/v1/categories/#{category.slug}", params: { category: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "admin can delete the category" do
    category = Category.create!(name: "Disposable")
    sign_in_as(@admin)
    assert_difference("Category.count", -1) do
      delete "/api/v1/categories/#{category.slug}"
    end
    assert_response :no_content
  end

  test "destroy cascades to its skills" do
    category = Category.create!(name: "With Skills")
    Skill.create!(title: "Child", category: category)
    sign_in_as(@admin)
    assert_difference("Category.count", -1) do
      assert_difference("Skill.count", -1) do
        delete "/api/v1/categories/#{category.slug}"
      end
    end
    assert_response :no_content
  end
end
