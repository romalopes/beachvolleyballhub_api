require "test_helper"

# Request tests for the Groups API (Phase A / Decision D23).
#
# Groups are reusable participant rosters (squads) for assessment sessions.
# They are a selection aid, not an authorization boundary.
# Full catalogue read is open to training managers (coach/curator/admin), while
# authenticated users have a narrow joinable catalogue for their organisations.
# Any player, coach, curator, or admin can create a group. Updates, deletion,
# and membership manipulation retain their existing ownership/management rules.
# Deleting a group with associated assessment sessions is refused (archive instead).
class Api::V1::GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)         # coach + admin
    @owner = users(:six)         # coach: created u19_squad fixture
    @other_coach = users(:three) # coach: created private_squad fixture
    @curator = users(:four)      # curator: training manager
    @player_user = users(:one)   # player role only
    @guest_user = users(:five)   # no group-creator role

    @u19 = groups(:u19_squad)
    @private_group = groups(:private_squad)
    @pedro = player_profiles(:pedro_player)
    @john = player_profiles(:john_player)
    # The roster is keyed on Account in the current schema.
    @pedro_account = accounts(:one)
    @john_account = accounts(:admin)
  end

  # --- Helpers ---

  def json
    JSON.parse(response.body)
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def patch_json(path, payload)
    patch path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  # --- Authentication & Authorization ---

  test "index requires authentication" do
    get api_v1_groups_path
    assert_response :unauthorized
  end

  test "index refuses player role" do
    sign_in_as(@player_user)
    get api_v1_groups_path
    assert_response :forbidden
  end

  test "player joinable index lists active groups in their organisations with summary metadata" do
    account = Account.create!(user: @player_user)
    club = organisations(:sydney_club)
    OrganisationMembership.create!(
      organisation: club, account: account, memberable: account,
      role: "member", status: "active"
    )
    joinable = Group.create!(
      name: "Player joinable squad", organisation: club, created_by: @owner
    )
    joinable.group_memberships.create!(
      account: @owner.account, memberable: @owner.account,
      role: "owner", status: "active", joined_at: Time.current
    )
    archived = Group.create!(
      name: "Archived joinable squad", organisation: club, created_by: @owner,
      status: "archived"
    )
    archived.group_memberships.create!(
      account: @owner.account, memberable: @owner.account,
      role: "owner", status: "active", joined_at: Time.current
    )
    already_joined = groups(:sydney_club_squad)
    already_joined.group_memberships.create!(
      account: account, memberable: account, role: "member", status: "pending"
    )

    sign_in_as(@player_user)
    get api_v1_groups_path, params: { joinable: 1, status: "all" }

    assert_response :success
    groups_by_name = json["data"].index_by { |group| group["name"] }
    assert groups_by_name.key?(joinable.name)
    assert_not groups_by_name.key?(archived.name)
    assert_not groups_by_name.key?(already_joined.name)
    assert_not groups_by_name.key?(groups(:northern_club_squad).name)
    assert_equal 1, groups_by_name.dig(joinable.name, "player_count")
    assert_equal club.name, groups_by_name.dig(joinable.name, "organisation", "name")
  end

  test "curator can read index and create groups" do
    sign_in_as(@curator)
    get api_v1_groups_path
    assert_response :success

    assert_difference "Group.count", 1 do
      post_json api_v1_groups_path, { group: { name: "Curator Group" } }
    end
    assert_response :created
    assert_equal @curator.id, json["group"]["created_by"]["id"]
  end

  test "player can create a group" do
    sign_in_as(@player_user)

    assert_difference "Group.count", 1 do
      post_json api_v1_groups_path, { group: { name: "Player Group" } }
    end

    assert_response :created
    assert_equal @player_user.id, json["group"]["created_by"]["id"]
  end

  test "a profile creator can add and remove their recorded coach profile" do
    profile = CoachProfile.new(display_name: "Creator managed coach")
    ProfileOwnership.stamp!(profile, @other_coach)
    profile.save!
    sign_in_as(@other_coach)

    post "#{api_v1_groups_path}/#{@u19.id}/memberships/profile", params: {
      memberable_type: "CoachProfile", memberable_id: profile.id
    }

    assert_response :created
    membership = @u19.group_memberships.find_by!(memberable: profile)
    assert_equal "active", membership.status

    delete "#{api_v1_groups_path}/#{@u19.id}/memberships/profile", params: {
      memberable_type: "CoachProfile", memberable_id: profile.id
    }

    assert_response :success
    assert_equal "ended", membership.reload.status
  end

  test "a profile creator cannot add somebody else's profile" do
    profile = CoachProfile.new(display_name: "Other creator coach")
    ProfileOwnership.stamp!(profile, @owner)
    profile.save!
    sign_in_as(@other_coach)

    post "#{api_v1_groups_path}/#{@u19.id}/memberships/profile", params: {
      memberable_type: "CoachProfile", memberable_id: profile.id
    }

    assert_response :forbidden
  end

  test "user without a group-creator role cannot create a group" do
    sign_in_as(@guest_user)

    assert_no_difference "Group.count" do
      post_json api_v1_groups_path, { group: { name: "Blocked Group" } }
    end

    assert_response :forbidden
  end

  # --- Index & Search ---

  test "index lists active groups visible to the caller" do
    sign_in_as(@owner)
    get api_v1_groups_path
    assert_response :success

    body = json
    assert_kind_of Array, body["data"]
    assert_kind_of Array, body["groups"]
    names = body["data"].map { |g| g["name"] }
    assert_includes names, "U19 squad"
    assert_not_includes names, "Private squad" # private to other_coach
  end

  test "index includes private groups for admins and curators" do
    sign_in_as(@admin)
    get api_v1_groups_path
    assert_response :success

    names = json["data"].map { |g| g["name"] }
    assert_includes names, "U19 squad"
    assert_includes names, "Private squad"
  end

  test "index filters by search query" do
    sign_in_as(@admin)
    get api_v1_groups_path, params: { q: "U19" }
    assert_response :success

    names = json["data"].map { |g| g["name"] }
    assert_includes names, "U19 squad"
    assert_not_includes names, "Private squad"
  end

  test "index filters by status" do
    @u19.update!(status: "archived")
    sign_in_as(@admin)

    get api_v1_groups_path
    names = json["data"].map { |g| g["name"] }
    assert_not_includes names, "U19 squad"

    get api_v1_groups_path, params: { status: "archived" }
    archived_names = json["data"].map { |g| g["name"] }
    assert_includes archived_names, "U19 squad"
  end

  test "index supports mine filter" do
    sign_in_as(@owner)
    get api_v1_groups_path, params: { mine: 1 }
    assert_response :success

    names = json["data"].map { |g| g["name"] }
    assert_includes names, "U19 squad"
    assert_equal 1, names.length
  end

  # --- Show ---

  test "show returns detailed group with members" do
    sign_in_as(@owner)
    get api_v1_group_path(@u19)
    assert_response :success

    group_data = json["group"]
    assert_equal @u19.id, group_data["id"]
    assert_equal "U19 squad", group_data["name"]
    # Pedro plus the fixture owner, who is on the roster like anybody else.
    assert_equal 2, group_data["player_count"]
    assert_equal 2, group_data["members"].length
    # Found by account, not by position: Rails derives fixture ids from a hash of
    # the label, so the members list is not in fixture-declaration order.
    pedro = group_data["members"].find { |m| m["account_id"] == @pedro_account.id }
    assert_not_nil pedro
    assert_equal "John Smith", pedro["name"]
    assert_equal "John Smith", pedro["name"]
    # Ownership travels with the membership, not with `created_by`.
    assert_equal "Maria Silva", group_data["owner"]["name"]
  end

  test "show supports slug lookup" do
    sign_in_as(@owner)
    get api_v1_group_path(@u19.slug)
    assert_response :success
    assert_equal @u19.id, json["group"]["id"]
  end

  test "show returns 404 for another coach's private group" do
    sign_in_as(@owner)
    get api_v1_group_path(@private_group)
    assert_response :not_found
  end

  test "show allows owner or admin to view private group" do
    sign_in_as(@other_coach)
    get api_v1_group_path(@private_group)
    assert_response :success
  end

  # --- Create ---

  test "create creates a new group with optional initial players" do
    sign_in_as(@owner)

    payload = {
      group: {
        name: "Morning Elite",
        description: "Competitive training group",
        visibility: "shared"
      },
      account_ids: [ @john_account.id, @pedro_account.id ]
    }

    assert_difference "Group.count", 1 do
      # Two asked for, plus the creator's own owner membership: a group with no
      # owner cannot be managed by anybody (§2.6).
      assert_difference "GroupMembership.count", 3 do
        post_json api_v1_groups_path, payload
      end
    end

    assert_response :created
    group_data = json["group"]
    assert_equal "Morning Elite", group_data["name"]
    assert_equal "morning-elite", group_data["slug"]
    # The two asked for, plus the creator, who is on their own roster as owner.
    assert_equal 3, group_data["player_count"]
    assert_equal @owner.id, group_data["created_by"]["id"]
    assert_equal @owner.account.id, group_data["owner"]["id"]
  end

  test "create validates unique name" do
    sign_in_as(@owner)

    post_json api_v1_groups_path, { group: { name: "u19 squad" } }
    assert_response :unprocessable_entity
    assert json["errors"].any? { |e| e.downcase.include?("name") }
  end

  # --- Update ---

  test "update modifies group details and syncs members" do
    sign_in_as(@owner)

    patch_json api_v1_group_path(@u19), {
      group: { name: "U19 Premier Squad", description: "Updated description" },
      account_ids: [ @john_account.id ]
    }

    assert_response :success
    assert_equal "U19 Premier Squad", json["group"]["name"]
    assert_equal "Updated description", json["group"]["description"]
    # John, plus the owner: syncing the roster is not a way to lose the owner.
    assert_equal 2, json["group"]["player_count"]
    # Looked up by account rather than by position: the members list is ordered by
    # membership id, and the owner's row predates the one just created.
    member = json["group"]["members"].find { |m| m["account_id"] == @john_account.id }
    assert_not_nil member
    assert_equal "Admin User", member["name"]
  end

  test "update is forbidden for another coach who does not own the group" do
    sign_in_as(@other_coach)

    patch_json api_v1_group_path(@u19), { group: { name: "Hacked" } }
    assert_response :forbidden
  end

  test "admin can update any group" do
    sign_in_as(@admin)

    patch_json api_v1_group_path(@u19), { group: { description: "Admin edit" } }
    assert_response :success
    assert_equal "Admin edit", json["group"]["description"]
  end

  # --- Destroy ---

  test "destroy deletes group if not used in assessment sessions" do
    sign_in_as(@owner)

    assert_difference "Group.count", -1 do
      delete api_v1_group_path(@u19)
    end

    assert_response :success
    assert_equal "Group deleted successfully", json["message"]
  end

  test "destroy refuses to delete group when referenced by assessment sessions" do
    sign_in_as(@owner)
    session = assessment_sessions(:draft_squad)
    session.update!(group: @u19)

    assert_no_difference "Group.count" do
      delete api_v1_group_path(@u19)
    end

    assert_response :unprocessable_entity
    assert json["errors"].any? { |e| e.include?("assessment sessions") }
  end

  # --- the group's organisation ---------------------------------------------

  test "create with an accountless profile memberable rosters the profile" do
    sign_in_as(@owner)
    profile = PlayerProfile.create!(display_name: "Unclaimed Prospect")
    OrganisationMembership.create!(
      organisation: organisations(:sydney_club), memberable: profile,
      role: "member", status: "active"
    )

    assert_difference "GroupMembership.count", 2 do
      post_json api_v1_groups_path, {
        group: { name: "Prospect squad", organisation_id: organisations(:sydney_club).id },
        memberables: [ { type: "PlayerProfile", id: profile.id } ]
      }
    end

    assert_response :created
    membership = GroupMembership.find_by!(group: Group.find_by!(name: "Prospect squad"), memberable: profile)
    assert_equal "active", membership.status
    assert_nil membership.account_id
  end

  test "a member creates a group for an organisation they are actually in" do
    # @owner is an active member (owner) of Sydney Beach Volleyball Club.
    sign_in_as(@owner)

    assert_difference "Group.count", 1 do
      post_json api_v1_groups_path, {
        group: {
          # Not "U19 squad": that fixture already exists and the name is unique.
          name: "Sydney U19 squad",
          organisation_id: organisations(:sydney_club).id
        }
      }
    end

    assert_response :created
    assert_equal "Sydney Beach Volleyball Club",
                 json["group"]["organisation"]["name"]
  end

  test "a coach creates a group when organisation membership is on their coach profile" do
    # @owner belongs to Sydney Beach Volleyball Club through coach_profiles(:maria_coach),
    # not through organisation_memberships.account_id. The organisation picker and
    # submit authorization must agree that this still means the signed-in person is
    # active in the club.
    OrganisationMembership.where(organisation: organisations(:sydney_club), account: @owner.account).destroy_all

    sign_in_as(@owner)

    assert_difference "Group.count", 1 do
      post_json api_v1_groups_path, {
        group: {
          name: "Profile Membership Squad",
          organisation_id: organisations(:sydney_club).id
        }
      }
    end

    assert_response :created
    assert_equal organisations(:sydney_club).id, json["group"]["organisation"]["id"]
  end

  test "a non-member cannot create a group for an organisation they do not belong to" do
    # Naming an organisation is not membership of it. users(:three) belongs to none.
    sign_in_as(@other_coach)

    assert_no_difference "Group.count" do
      post_json api_v1_groups_path, {
        group: {
          name: "Outsider squad",
          organisation_id: organisations(:sydney_club).id
        }
      }
    end

    assert_response :forbidden
    assert_match(/active member/, json["errors"].first)
  end

  test "admin and curator can create a group for any organisation" do
    [ @admin, @curator ].each do |user|
      sign_in_as(user)

      assert_difference "Group.count", 1 do
        post_json api_v1_groups_path, {
          group: {
            name: "#{user.roles.first.name.capitalize} Northern Squad",
            organisation_id: organisations(:northern_club).id
          }
        }
      end

      assert_response :created
      assert_equal organisations(:northern_club).id, json["group"]["organisation"]["id"]
    end
  end

  test "being a group member does not grant organisation membership authority" do
    # users(:three) owns the independent private_squad but is not a member of
    # Sydney Beach Volleyball Club.
    sign_in_as(@other_coach)
    assert @private_group.group_memberships.exists?(account_id: @other_coach.account.id)
    assert_not OrganisationMembership.exists?(account_id: @other_coach.account.id,
                                             organisation: organisations(:sydney_club),
                                             status: "active")

    assert_no_difference "Group.count" do
      post_json api_v1_groups_path, {
        group: {
          name: "Group Member Without Club Standing",
          organisation_id: organisations(:sydney_club).id
        }
      }
    end

    assert_response :forbidden
  end

  test "an account outside the group's organisation cannot be added to it" do
    sign_in_as(@owner)
    @u19.update!(organisation: organisations(:sydney_club))
    outsider = accounts(:admin)
    assert_not @u19.shares_organisation?([], account_ids: [ outsider.id ])

    assert_no_difference "GroupMembership.count" do
      post_json members_api_v1_group_path(@u19), { account_ids: [ outsider.id ] }
    end

    assert_response :unprocessable_entity
    assert_match(/active member/, json["errors"].first)
  end

  test "an account inside the group's organisation can be added to it" do
    sign_in_as(@owner)
    @u19.update!(organisation: organisations(:sydney_club))
    insider = accounts(:admin)
    OrganisationMembership.create!(organisation: organisations(:sydney_club),
                                   account: insider,
                                   memberable: insider,
                                   role: "member",
                                   status: "active",
                                   joined_at: Time.current)

    assert_difference "GroupMembership.count", 1 do
      post_json members_api_v1_group_path(@u19), { account_ids: [ insider.id ] }
    end

    assert_response :success
    assert_includes @u19.reload.accounts, insider
  end

  test "an accountless player profile can be added to a group in its own right" do
    # §4.4: the subject is polymorphic, so a profile with no Account can sit on a
    # roster exactly as it can on an organisation roster. `pedro_player` has no
    # account and is an active member of sydney_club (accountless_club_member).
    sign_in_as(@owner)
    @u19.update!(organisation: organisations(:sydney_club))
    assert_nil @pedro.account_id

    assert_difference "GroupMembership.count", 1 do
      post_json members_api_v1_group_path(@u19),
                { memberable_type: "PlayerProfile", memberable_id: @pedro.id }
    end

    assert_response :success
    membership = @u19.group_memberships.find_by(memberable: @pedro)
    assert membership
    assert_equal "PlayerProfile", membership.memberable_type
    assert_nil membership.account_id
  end

  test "a profile outside the group's organisation cannot be added to it" do
    sign_in_as(@owner)
    # A fresh group owned by the caller, placed in an organisation `pedro_player`
    # does not belong to (he is a member of sydney_club, not northern_club).
    group = Group.create!(name: "Northern squad", organisation: organisations(:northern_club), created_by: @owner)
    group.group_memberships.create!(account: @owner.account, memberable: @owner.account,
                                    role: "owner", status: "active", joined_at: Time.current)
    assert_not group.shares_organisation?([], group.organisation_id, memberables: [ @pedro ])

    assert_no_difference "GroupMembership.count" do
      post_json members_api_v1_group_path(group),
                { memberable_type: "PlayerProfile", memberable_id: @pedro.id }
    end

    assert_response :unprocessable_entity
    assert_match(/active member/, json["errors"].first)
  end

  test "a profile subject that does not exist is refused" do
    sign_in_as(@owner)

    assert_no_difference "GroupMembership.count" do
      post_json members_api_v1_group_path(@u19),
                { memberable_type: "PlayerProfile", memberable_id: 0 }
    end

    assert_response :unprocessable_entity
  end

  test "a profile cannot be granted the owner role" do
    sign_in_as(@owner)
    @u19.update!(organisation: organisations(:sydney_club))

    assert_no_difference "GroupMembership.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        @u19.group_memberships.create!(memberable: @pedro, role: "owner", joined_at: Time.current)
      end
    end
  end

  test "a group cannot be moved to an organisation the caller does not belong to" do
    # Firing *before* the roster check: naming an organisation is not membership of
    # it, and that is the more specific fact about this request. The roster rule
    # itself is covered on the model, where it is not masked by this guard.
    sign_in_as(@owner)

    patch_json api_v1_group_path(@u19), {
      group: { organisation_id: organisations(:volleyball_australia).id }
    }

    assert_response :forbidden
    assert_match(/active member/, json["errors"].first)
    assert_nil @u19.reload.organisation_id
  end

  # --- Member Management ---

  test "add_members adds accounts to the group without duplicates" do
    sign_in_as(@owner)

    # Pedro is already on the roster, so only John is really added.
    assert_difference "GroupMembership.count", 1 do
      post_json members_api_v1_group_path(@u19),
                { account_ids: [ @john_account.id, @pedro_account.id ] }
    end

    assert_response :success
    # Owner + Pedro + John.
    assert_equal 3, json["group"]["player_count"]
    assert_equal 1, json["added"]
  end

  test "remove_member ends the membership rather than deleting it" do
    sign_in_as(@owner)

    # §2.5: the row survives as history, so the count of rows does not change.
    assert_no_difference "GroupMembership.count" do
      delete "#{api_v1_groups_path}/#{@u19.id}/members/#{@pedro_account.id}"
    end

    assert_response :success
    # Owner only; Pedro is no longer a current member.
    assert_equal 1, json["group"]["player_count"]
    assert_equal @pedro_account.id, json["removed"]

    membership = @u19.group_memberships.find_by(account: @pedro_account)
    assert_predicate membership, :ended?
    assert_not_nil membership.left_at
  end

  test "remove_member will not end the owner's membership" do
    # A group with no owner cannot be managed by anybody, which is the failure
    # §2.6 exists to prevent.
    sign_in_as(@owner)

    delete "#{api_v1_groups_path}/#{@u19.id}/members/#{@owner.account.id}"

    assert_response :unprocessable_entity
    assert @u19.reload.group_memberships.owners.exists?(account_id: @owner.account.id)
  end

  test "remove_member returns 404 if the account is not in the group" do
    sign_in_as(@owner)

    delete "#{api_v1_groups_path}/#{@u19.id}/members/#{@john_account.id}"
    assert_response :not_found
  end

  # --- self-service join ------------------------------------------------------

  test "a coach can join an open group as an ordinary member" do
    # @other_coach owns private_squad but has no row on u19 — a genuine first join.
    sign_in_as(@other_coach)

    assert_difference "GroupMembership.count", 1 do
      post "#{api_v1_groups_path}/#{@u19.id}/join"
    end

    assert_response :created
    membership = @u19.group_memberships.find_by(account: @other_coach.account)
    assert_equal "member", membership.role
    assert_equal "active", membership.status
    assert_not_nil membership.joined_at
  end

  test "joining twice conflicts rather than duplicating" do
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    assert_response :created

    assert_no_difference "GroupMembership.count" do
      post "#{api_v1_groups_path}/#{@u19.id}/join"
    end

    assert_response :conflict
    assert_match(/already a member/, json["error"])
  end

  test "rejoining after leaving reactivates the same row rather than adding one" do
    membership = @u19.group_memberships.create!(
      account: @other_coach.account, role: "member", status: "ended",
      joined_at: 1.year.ago, left_at: 1.month.ago
    )

    sign_in_as(@other_coach)
    assert_no_difference "GroupMembership.count" do
      post "#{api_v1_groups_path}/#{@u19.id}/join"
    end

    assert_response :created
    reloaded = GroupMembership.find(membership.id)
    assert_equal "active", reloaded.status
    assert_nil reloaded.left_at
    assert_not_nil reloaded.joined_at
  end

  test "an active non-owner can leave a group" do
    membership = @u19.group_memberships.create!(
      account: @other_coach.account,
      role: "member",
      status: "active",
      joined_at: Time.current,
    )
    sign_in_as(@other_coach)

    delete "#{api_v1_groups_path}/#{@u19.id}/memberships/leave"

    assert_response :success
    assert_not json["removed"]
    assert_equal membership.id, json["membership_id"]
    membership.reload
    assert_equal "ended", membership.status
    assert_not_nil membership.left_at
  end

  test "a group owner cannot leave without transferring ownership" do
    sign_in_as(@owner)

    delete "#{api_v1_groups_path}/#{@u19.id}/memberships/leave"

    assert_response :unprocessable_entity
    assert_match(/owner/, json["errors"].first)
    assert_equal "active", @u19.group_memberships.owners.first!.reload.status
  end

  test "a non-member cannot leave a group" do
    sign_in_as(@other_coach)

    delete "#{api_v1_groups_path}/#{@u19.id}/memberships/leave"

    assert_response :not_found
    assert_match(/not an active member/, json["errors"].first)
  end

  test "an approval-required group records a join as pending, not active" do
    @u19.update!(requires_approval: true)
    sign_in_as(@other_coach)

    assert_difference "GroupMembership.count", 1 do
      post "#{api_v1_groups_path}/#{@u19.id}/join"
    end

    assert_response :created
    membership = @u19.group_memberships.find_by(account: @other_coach.account)
    assert_equal "member", membership.role
    assert_equal "pending", membership.status
    # A request has not joined yet: no stint begins until the owner approves.
    assert_nil membership.joined_at
    # Pending rows are not counted as squad members.
    assert_equal 2, @u19.reload.player_count
  end

  test "the group's owner approves a pending join request" do
    @u19.update!(requires_approval: true)
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    membership = @u19.group_memberships.find_by(account: @other_coach.account)
    assert_equal "pending", membership.status

    sign_out
    sign_in_as(@owner)
    post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{membership.id}/approve"

    assert_response :success
    membership.reload
    assert_equal "active", membership.status
    assert_not_nil membership.joined_at
  end

  test "a non-owner coach may not approve a group join request" do
    @u19.update!(requires_approval: true)
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    membership = @u19.group_memberships.find_by(account: @other_coach.account)

    # The requester themselves: being the asker is not authority over the roster.
    post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{membership.id}/approve"

    assert_response :forbidden
    assert_equal "pending", membership.reload.status
  end

  test "curator oversight may approve a group join request" do
    @u19.update!(requires_approval: true)
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    membership = @u19.group_memberships.find_by(account: @other_coach.account)

    sign_out
    sign_in_as(@curator)
    post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{membership.id}/approve"

    assert_response :success
    assert_equal "active", membership.reload.status
  end

  test "a requester may withdraw their own pending join request" do
    @u19.update!(requires_approval: true)
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    membership = @u19.group_memberships.find_by(account: @other_coach.account)

    # A pending request records no stint, so it is removed outright (§: the one
    # exception to end-don't-delete).
    assert_difference "GroupMembership.count", -1 do
      post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{membership.id}/reject"
    end

    assert_response :success
    assert json["removed"]
    assert_not GroupMembership.exists?(membership.id)
  end

  test "the owner rejects a pending join request" do
    @u19.update!(requires_approval: true)
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    membership = @u19.group_memberships.find_by(account: @other_coach.account)

    sign_out
    sign_in_as(@owner)
    post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{membership.id}/reject"

    assert_response :success
    assert_not GroupMembership.exists?(membership.id)
  end

  test "only pending group requests can be approved" do
    sign_in_as(@other_coach)
    post "#{api_v1_groups_path}/#{@u19.id}/join"
    assert_response :created
    membership = @u19.group_memberships.find_by(account: @other_coach.account)
    assert_equal "active", membership.status

    sign_out
    sign_in_as(@owner)
    post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{membership.id}/approve"

    assert_response :unprocessable_entity
    assert_match(/pending/, json["errors"].first)
  end

  test "approving a membership from another group is a 404" do
    sign_in_as(@admin)
    other_row = @private_group.group_memberships.owners.first

    post "#{api_v1_groups_path}/#{@u19.id}/memberships/#{other_row.id}/approve"

    assert_response :not_found
  end

  test "an archived group does not accept joins" do
    @u19.update!(status: "archived")
    sign_in_as(@other_coach)

    post "#{api_v1_groups_path}/#{@u19.id}/join"

    assert_response :unprocessable_entity
    assert_match(/archived/, json["errors"].first)
  end

  test "a join to a group bound to an organisation requires active membership there" do
    @u19.update!(organisation: organisations(:sydney_club))
    # accounts(:three) is not in Sydney Beach Volleyball Club.
    sign_in_as(@other_coach)

    post "#{api_v1_groups_path}/#{@u19.id}/join"

    assert_response :unprocessable_entity
    assert_match(/organisation/, json["errors"].first)
  end

  test "the join policy is settable by the group's owner" do
    sign_in_as(@owner)

    patch_json "#{api_v1_groups_path}/#{@u19.id}", group: { requires_approval: true }

    assert_response :success
    assert_predicate @u19.reload, :requires_approval?
    assert json["group"]["requires_approval"]
    assert json["group"]["approval_required"]
    assert json["group"]["can_approve_members"]
  end

  test "a guest may not join a group" do
    post "#{api_v1_groups_path}/#{@u19.id}/join"

    assert_response :unauthorized
  end
  test "curator can delete an unused group" do
    sign_in_as(@curator)
    assert_difference("Group.count", -1) { delete api_v1_group_path(@u19) }
    assert_response :success
  end

  test "another coach cannot delete a group" do
    sign_in_as(@other_coach)
    assert_no_difference("Group.count") { delete api_v1_group_path(@u19) }
    assert_response :forbidden
  end

  test "owner membership cannot be ended directly" do
    membership = @u19.group_memberships.owners.first!
    assert_raises(ActiveRecord::RecordInvalid) { membership.end_membership! }
    assert_equal "active", membership.reload.status
  end

  test "curator can edit archive and restore a group" do
    sign_in_as(@curator)
    patch_json api_v1_group_path(@u19), { group: { name: "Curator updated squad", status: "archived" } }
    assert_response :success
    assert_equal "archived", @u19.reload.status
    assert_equal "Curator updated squad", @u19.name
    patch_json api_v1_group_path(@u19), { group: { status: "active" } }
    assert_response :success
    assert_equal "active", @u19.reload.status
  end

  test "another coach cannot edit or archive a group" do
    sign_in_as(@other_coach)
    original_name = @u19.name
    patch_json api_v1_group_path(@u19), { group: { name: "Unauthorized", status: "archived" } }
    assert_response :forbidden
    assert_equal original_name, @u19.reload.name
    assert_equal "active", @u19.status
  end

end
