require "test_helper"

class Api::V1::PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @public_user = users(:one)
    @trainer = users(:three)
    @other_coach = users(:six)
    @admin = users(:two)
    @curator = users(:four)
  end

  test "index returns active player profiles" do
    sign_in_as(@admin)
    get api_v1_players_path
    assert_response :success
    ids = JSON.parse(response.body).fetch("data").map { |row| row.fetch("id") }
    assert_includes ids, player_profiles(:john_player).id
    assert_includes ids, player_profiles(:pedro_player).id
  end

  test "regular account scopes to linked profiles" do
    linked = player_profiles(:john_player)
    linked.update_columns(account_id: accounts(:one).id)
    sign_in_as(accounts(:one).user)
    get api_v1_players_path
    assert_response :success
    assert_equal [ linked.id ], JSON.parse(response.body).fetch("data").map { |row| row.fetch("id") }
    get api_v1_player_path(linked)
    assert_response :success
  end

  test "create permits player and curator roles and stamps creator account" do
    sign_in_as(@public_user)
    post api_v1_players_path, params: player_create_params
    assert_response :created
    player_profile = PlayerProfile.find(JSON.parse(response.body).fetch("id"))
    assert_equal @public_user, player_profile.created_by
    assert_equal @public_user.account, player_profile.created_by_account

    sign_out
    sign_in_as(@curator)
    post api_v1_players_path, params: player_create_params
    assert_response :created
    profile = PlayerProfile.find(JSON.parse(response.body).fetch("id"))
    assert_equal @curator, profile.created_by
    assert_equal @curator.account, profile.created_by_account

    sign_out
    sign_in_as(@trainer)
    post api_v1_players_path, params: player_create_params
    assert_response :created
    profile = PlayerProfile.find(JSON.parse(response.body).fetch("id"))
    assert_equal "Test User", profile.display_name
    assert_equal "test.user@example.com", profile.email
    assert_nil profile.account_id
    assert_equal accounts(:three).id, profile.created_by_account_id
  end

  test "client supplied ownership fields are ignored" do
    sign_in_as(@trainer)
    post api_v1_players_path, params: {
      player: { player_profile: { display_name: "Untrusted Owner", account_id: accounts(:one).id, created_by_account_id: accounts(:one).id } }
    }
    assert_response :created
    profile = PlayerProfile.find(JSON.parse(response.body).fetch("id"))
    assert_nil profile.account_id
    assert_equal accounts(:three).id, profile.created_by_account_id
  end

  test "index paginates player profiles" do
    sign_in_as(@admin)
    baseline = PlayerProfile.count
    25.times { |index| PlayerProfile.create!(display_name: "Paged #{format('%02d', index)}") }
    get api_v1_players_path
    first = JSON.parse(response.body)
    assert_equal 20, first.dig("meta", "per_page")
    assert_equal baseline + 25, first.dig("meta", "total")
    get api_v1_players_path, params: { page: 2 }
    second = JSON.parse(response.body)
    assert_empty first.fetch("data").map { |row| row.fetch("id") } & second.fetch("data").map { |row| row.fetch("id") }
  end

  test "invalid profile attributes return validation errors" do
    sign_in_as(@admin)
    post api_v1_players_path, params: { player: { player_profile: { display_name: "" } } }
    assert_response :unprocessable_entity
    patch api_v1_player_path(player_profiles(:pedro_player)), params: { player: { player_profile: { visibility: "bogus" } } }
    assert_response :unprocessable_entity
  end

  test "create atomically attaches a player profile to a selected organisation and group" do
    sign_in_as(@admin)

    assert_difference [ "PlayerProfile.count", "OrganisationMembership.count", "GroupMembership.count" ], 1 do
      post api_v1_players_path, params: player_create_params.deep_merge(
        player: {
          organisation_id: organisations(:sydney_club).id,
          group_id: groups(:sydney_club_squad).id
        }
      )
    end

    assert_response :created
    profile = PlayerProfile.find(JSON.parse(response.body).fetch("id"))
    assert OrganisationMembership.exists?(organisation: organisations(:sydney_club), memberable: profile, role: "member", status: "active")
    assert GroupMembership.exists?(group: groups(:sydney_club_squad), memberable: profile, role: "member", status: "active")
  end

  test "cross-organisation group selection rolls back player profile creation" do
    sign_in_as(@admin)

    assert_no_difference [ "PlayerProfile.count", "OrganisationMembership.count", "GroupMembership.count" ] do
      post api_v1_players_path, params: player_create_params.deep_merge(
        player: {
          organisation_id: organisations(:sydney_club).id,
          group_id: groups(:northern_club_squad).id
        }
      )
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors"), "The selected group does not belong to the selected organisation."
  end

  test "a profile creator cannot attach a player to an organisation they do not belong to" do
    sign_in_as(@trainer)

    assert_no_difference [ "PlayerProfile.count", "OrganisationMembership.count", "GroupMembership.count" ] do
      post api_v1_players_path, params: player_create_params.deep_merge(
        player: { organisation_id: organisations(:sydney_club).id }
      )
    end

    assert_response :forbidden
  end

  test "show and update use player profile attributes" do
    player = player_profiles(:pedro_player)
    sign_in_as(@admin)
    get api_v1_player_path(player)
    assert_response :success
    assert_equal player.id, JSON.parse(response.body).fetch("id")
    patch api_v1_player_path(player), params: { player: { player_profile: { level: "advanced", email: "player@example.com" } } }
    assert_response :success
    assert_equal "advanced", player.reload.level
    assert_equal "player@example.com", player.email
    assert_equal "player@example.com", JSON.parse(response.body).fetch("email")
  end

  test "show exposes linked account memberships at the profile level" do
    player = player_profiles(:john_player)
    sign_in_as(@admin)

    get api_v1_player_path(player)

    assert_response :success
    body = JSON.parse(response.body)
    organisation_membership = body.fetch("organisation_memberships").find { |row| row.fetch("id") == organisation_memberships(:club_player).id }
    group_membership = body.fetch("group_memberships").find { |row| row.fetch("id") == group_memberships(:u19_squad_pedro).id }

    assert_equal organisations(:sydney_club).name, organisation_membership.dig("organisation", "name")
    assert_equal groups(:u19_squad).name, group_membership.dig("group", "name")
    assert_nil group_membership.dig("group", "organisation")
  end

  test "show exposes profile-held memberships before the player is claimed" do
    player = player_profiles(:pedro_player)
    sign_in_as(@admin)

    get api_v1_player_path(player)

    assert_response :success
    body = JSON.parse(response.body)
    organisation_membership = body.fetch("organisation_memberships").find { |row| row.fetch("id") == organisation_memberships(:accountless_club_member).id }
    group_membership = body.fetch("group_memberships").find { |row| row.fetch("id") == group_memberships(:u19_squad_accountless_player).id }

    assert_nil organisation_membership.fetch("account_id")
    assert_equal "PlayerProfile", organisation_membership.fetch("memberable_type")
    assert_equal player.id, organisation_membership.fetch("memberable_id")
    assert_equal organisations(:sydney_club).name, organisation_membership.dig("organisation", "name")

    assert_nil group_membership.fetch("account_id")
    assert_equal "PlayerProfile", group_membership.fetch("memberable_type")
    assert_equal player.id, group_membership.fetch("memberable_id")
    assert_equal groups(:u19_squad).name, group_membership.dig("group", "name")
  end

  test "private players are hidden from unrelated coaches but visible to owner and curator" do
    private_player = private_player_owned_by(@trainer)
    sign_in_as(@other_coach)
    get api_v1_players_path
    assert_not_includes JSON.parse(response.body).fetch("data").map { |row| row.fetch("id") }, private_player.id
    get api_v1_player_path(private_player)
    assert_response :not_found

    sign_out
    sign_in_as(@trainer)
    get api_v1_player_path(private_player)
    assert_response :success

    sign_out
    sign_in_as(@curator)
    get api_v1_player_path(private_player)
    assert_response :success
  end

  test "only owner or admin can flip visibility" do
    private_player = private_player_owned_by(@trainer)
    sign_in_as(@other_coach)
    patch api_v1_player_path(private_player), params: { player: { player_profile: { visibility: "shared" } } }
    assert_response :not_found

    private_player.update!(visibility: "shared")
    patch api_v1_player_path(private_player), params: { player: { player_profile: { visibility: "private" } } }
    assert_response :forbidden

    sign_out
    sign_in_as(@trainer)
    patch api_v1_player_path(private_player), params: { player: { player_profile: { visibility: "private" } } }
    assert_response :success

    sign_out
    sign_in_as(@admin)
    patch api_v1_player_path(private_player), params: { player: { player_profile: { visibility: "shared" } } }
    assert_response :success
  end

  test "status filter exposes archived players on request" do
    sign_in_as(@admin)
    player = player_profiles(:pedro_player)
    player.update!(status: "archived")
    get api_v1_players_path
    assert_not_includes JSON.parse(response.body).fetch("data").map { |row| row.fetch("id") }, player.id
    get api_v1_players_path, params: { status: "archived" }
    assert_includes JSON.parse(response.body).fetch("data").map { |row| row.fetch("id") }, player.id
  end

  test "show exposes assessment count and visible history" do
    sign_in_as(@trainer)
    get api_v1_player_path(player_profiles(:pedro_player))
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.fetch("assessment_count")
    assert_includes body.fetch("assessments").map { |row| row.fetch("id") }, assessments(:skill_active).id
  end

  private

  def private_player_owned_by(owner)
    profile = PlayerProfile.new(display_name: "Private Owned", visibility: "private", created_by: owner)
    ProfileOwnership.stamp!(profile, owner)
    profile.save!
    profile
  end

  def player_create_params
    { player: { player_profile: { display_name: "Test User", email: "test.user@example.com", preferred_position: "setter" } } }
  end
end