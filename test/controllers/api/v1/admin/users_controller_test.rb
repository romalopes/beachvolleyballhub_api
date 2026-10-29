require "test_helper"

class Api::V1::Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)    # coach + admin (the fixture admin)
    @coach = users(:three)  # coach role only
    @player = users(:one)   # player role only
  end

  test "index is paginated with meta" do
    sign_in_as(@admin)
    get "/api/v1/admin/users", params: { page: 1, per_page: 2 }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["data"].length
    assert_equal 1, body["meta"]["page"]
    assert_equal 2, body["meta"]["per_page"]
    assert_equal User.count, body["meta"]["total"]
    assert body["meta"]["total_pages"] >= 2
    # The admin itself is in the fixture set; page 1 holds the first two ids.
    assert_equal User.order(:id).limit(2).pluck(:id), body["data"].map { |u| u["id"] }
  end

  test "index defaults to 20 per page" do
    sign_in_as(@admin)
    get "/api/v1/admin/users"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 20, body["meta"]["per_page"]
  end

  test "index searches by email case-insensitively" do
    sign_in_as(@admin)
    get "/api/v1/admin/users", params: { search: @player.email_address.upcase }
    assert_response :success
    ids = JSON.parse(response.body)["data"].map { |u| u["id"] }
    assert_includes ids, @player.id
    refute ids.include?(@coach.id)
  end

  test "index with no match returns empty data with meta" do
    sign_in_as(@admin)
    get "/api/v1/admin/users", params: { search: "zzz-no-such-user" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_empty body["data"]
    assert_equal 0, body["meta"]["total"]
  end

  test "show includes account organisation and group memberships" do
    account_user = accounts(:one).user

    sign_in_as(@admin)
    get "/api/v1/admin/users/#{account_user.id}"

    assert_response :success
    account = JSON.parse(response.body)["account"]
    assert_includes account["organisation_memberships"].map { |membership| membership["organisation"]["name"] }, "Sydney Beach Volleyball Club"
    assert_includes account["group_memberships"].map { |membership| membership["group"]["name"] }, "U19 squad"
  end

  test "admin can create a user with an account and player role" do
    sign_in_as(@admin)
    email = "created-#{SecureRandom.hex(6)}@example.com"

    assert_difference [ "User.count", "Account.count", "ContactDetail.count" ], 1 do
      post "/api/v1/admin/users", params: {
        email_address: email,
        password: "password123",
        first_name: "John",
        last_name: "Doe"
      }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    user = User.find(body["id"])

    assert_equal email, user.email_address
    assert user.player?
    assert_equal "John", user.account.first_name
    assert_equal "Doe", user.account.last_name
    assert_equal email, user.account.email
    assert_equal "John", body["first_name"]
    assert_equal "Doe", body["last_name"]
  end

  test "admin user creation uses the email prefix when first name is omitted" do
    sign_in_as(@admin)
    email = "fallback-name-#{SecureRandom.hex(6)}@example.com"

    post "/api/v1/admin/users", params: {
      email_address: email,
      password: "password123"
    }, as: :json

    assert_response :created
    user = User.find(JSON.parse(response.body)["id"])
    assert_equal email.split("@", 2).first, user.account.first_name
  end

  test "invalid admin user creation does not persist partial records" do
    sign_in_as(@admin)

    assert_no_difference [ "User.count", "Account.count", "ContactDetail.count" ] do
      post "/api/v1/admin/users", params: {
        email_address: "not-an-email",
        password: "short",
        first_name: "John"
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].present?
  end

  test "admin user creation returns a message when the email already exists" do
    sign_in_as(@admin)

    assert_no_difference [ "User.count", "Account.count", "ContactDetail.count" ] do
      post "/api/v1/admin/users", params: {
        email_address: @player.email_address.upcase,
        password: "password123",
        first_name: "Duplicate",
        last_name: "User"
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "Email address has already been taken" ], JSON.parse(response.body)["errors"]
  end

  test "admin can remove a role from another user" do
    sign_in_as(@admin)
    delete "/api/v1/admin/users/#{@coach.id}/roles/coach"
    assert_response :success
    refute_includes JSON.parse(response.body)["roles"], "coach"
  end

  test "admin can remove their own non-admin role" do
    sign_in_as(@admin)
    assert @admin.has_role?(:coach)
    delete "/api/v1/admin/users/#{@admin.id}/roles/coach"
    assert_response :success
    roles = JSON.parse(response.body)["roles"]
    refute_includes roles, "coach"
    assert_includes roles, "admin"
  end

  test "admin cannot remove their own admin role" do
    sign_in_as(@admin)
    delete "/api/v1/admin/users/#{@admin.id}/roles/admin"
    assert_response :unprocessable_entity
    assert_equal "You cannot remove your own admin role", JSON.parse(response.body)["error"]
    assert @admin.reload.has_role?(:admin), "admin role should be preserved"
  end

  test "admin can remove another admin's admin role when another admin remains" do
    @coach.add_role(:admin) # now two admins exist
    sign_in_as(@admin)
    delete "/api/v1/admin/users/#{@coach.id}/roles/admin"
    assert_response :success
    refute_includes JSON.parse(response.body)["roles"], "admin"
    assert @admin.reload.has_role?(:admin), "the caller's own admin role is untouched"
  end

  test "self-guard takes precedence over the last-admin guard" do
    sign_in_as(@admin) # @admin is the only admin in fixtures
    delete "/api/v1/admin/users/#{@admin.id}/roles/admin"
    assert_response :unprocessable_entity
    assert_equal "You cannot remove your own admin role", JSON.parse(response.body)["error"]
  end

  test "guest cannot remove a role" do
    delete "/api/v1/admin/users/#{@coach.id}/roles/coach"
    assert_response :unauthorized
  end

  test "non-admin cannot remove a role" do
    sign_in_as(@player)
    delete "/api/v1/admin/users/#{@coach.id}/roles/coach"
    assert_response :forbidden
  end
end