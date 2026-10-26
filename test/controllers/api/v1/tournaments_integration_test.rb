require "test_helper"

# Request tests for the tournament detail, self-link and My Tournaments surface
# (Phase 7). Pinned here:
#   * participation requires authentication and is self-declared — no membership
#     or admin authority is needed to link an Account to a tournament;
#   * role/division rules are enforced server-side (non-player/coach roles cannot
#     select divisions; foreign and inactive divisions are rejected);
#   * re-submitting updates the single Account/tournament row rather than adding;
#   * unlinking is idempotent and allowed even after the event ends;
#   * `mine=1` scopes the directory to the caller's participations;
#   * detail is public and never leaks a participation for a guest;
#   * detail stamps `organisation.can_edit` with the same authority the
#     create/update actions enforce, so the client renders controls from it.
class Api::V1::TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organisation = organisations(:sydney_club)
    # users(:five) via accounts(:one): an active club *member* (not owner/admin),
    # so it exercises the self-link path that must not require management rights.
    @account = accounts(:one)
    @user = @account.user
    @admin = users(:two) # carries the admin role

    @tournament = Tournament.create!(
      name: "Sand Series Open",
      organisation: @organisation,
      created_by_account: @account,
      scope: "club",
      division_scheme: "letter",
      publication_state: "active",
      starts_at: 1.day.from_now,
      ends_at: 2.days.from_now,
      timezone: "UTC",
      all_day: false
    )
    @division_a = @tournament.divisions.create!(letter_level: "A", active: true)
    @division_b = @tournament.divisions.create!(letter_level: "B", active: true)
    @inactive_division = @tournament.divisions.create!(letter_level: "BB", active: false)
  end

  def json = JSON.parse(response.body)

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def delete_json(path)
    delete path, headers: { "Content-Type" => "application/json" }
  end

  # --- detail (public) --------------------------------------------------------

  test "guest can read a tournament detail with no participation" do
    get "/api/v1/tournaments/#{@tournament.id}"

    assert_response :success
    assert_equal @tournament.id, json["id"]
    assert_equal "Sand Series Open", json["name"]
    assert_nil json["my_participation"]
    assert_not json.key?("city")
    assert_not json.key?("state")
    assert_not json.key?("country")
  end

  test "directory search matches canonical location fields" do
    location = Location.create!(
      name: "Harbour Courts",
      locality: "Wollongong",
      administrative_area: "NSW",
      country_code: "AU",
      proposed_by_account: @account
    )
    @tournament.update!(location: location)

    get "/api/v1/tournaments", params: { search: "Wollongong" }

    assert_response :success
    assert_includes json["tournaments"].map { |row| row["id"] }, @tournament.id
  end

  test "create derives the creator from the authenticated account" do
    sign_in_as(@admin)
    authenticated_account = @admin.account
    forged_account = accounts(:three)

    post_json "/api/v1/tournaments", {
      organisation_id: @organisation.id,
      tournament: {
        name: "Authenticated Creator Open",
        organisation_id: @organisation.id,
        created_by_account_id: forged_account.id,
        scope: "club",
        division_scheme: "numbered",
        publication_state: "draft",
        timezone: "Australia/Sydney",
        all_day: true,
        starts_at: "2026-11-01",
        ends_at: "2026-11-02"
      }
    }

    assert_response :created
    created = Tournament.find(json.fetch("id"))
    assert_equal authenticated_account.id, created.created_by_account_id
    assert_not_equal forged_account.id, created.created_by_account_id
  end

  # --- participation (self-link) ---------------------------------------------

  test "unauthenticated participation is rejected" do
    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "player", division_ids: [ @division_a.id ] }

    assert_response :unauthorized
  end

  test "authenticated account can self-link with a role and active divisions" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "player", division_ids: [ @division_a.id ] }

    assert_response :success
    assert_equal "player", json["role"]
    assert_equal [ @division_a.id ], json["division_ids"]

    participation = TournamentParticipation.find_by(account: @account, tournament: @tournament)
    assert_not_nil participation
    assert_equal "player", participation.role
  end

  test "re-submitting updates the single existing participation row" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "player", division_ids: [ @division_a.id ] }
    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "coach", division_ids: [ @division_a.id, @division_b.id ] }

    assert_response :success
    assert_equal "coach", json["role"]
    assert_equal [ @division_a.id, @division_b.id ].sort, json["division_ids"].sort
    assert_equal 1, TournamentParticipation.where(account: @account, tournament: @tournament).count
  end

  test "non-player/coach roles cannot select divisions" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "referee", division_ids: [ @division_a.id ] }

    assert_response :unprocessable_entity
    assert_nil TournamentParticipation.find_by(account: @account, tournament: @tournament)
  end

  test "a forged inactive division is rejected" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "player", division_ids: [ @inactive_division.id ] }

    assert_response :unprocessable_entity
  end

  test "a division from another tournament is rejected" do
    sign_in_as(@user)

    other = Tournament.create!(
      name: "Other Open",
      organisation: @organisation,
      created_by_account: @account,
      scope: "club",
      division_scheme: "letter",
      publication_state: "active",
      starts_at: 3.days.from_now,
      ends_at: 4.days.from_now,
      timezone: "UTC",
      all_day: false
    )
    foreign = other.divisions.create!(letter_level: "A", active: true)

    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "player", division_ids: [ foreign.id ] }

    assert_response :unprocessable_entity
  end

  test "unlinking removes the participation and is idempotent" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/participate",
              participation: { role: "player", division_ids: [ @division_a.id ] }
    assert_response :success

    delete_json "/api/v1/tournaments/#{@tournament.id}/participate"
    assert_response :no_content
    assert_nil TournamentParticipation.find_by(account: @account, tournament: @tournament)

    delete_json "/api/v1/tournaments/#{@tournament.id}/participate"
    assert_response :no_content
  end

  # --- mine=1 (My Tournaments server-side) -----------------------------------

  test "mine=1 requires authentication" do
    get "/api/v1/tournaments", params: { mine: "1" }

    assert_response :unauthorized
  end

  test "mine=1 returns only the caller's tournaments" do
    sign_in_as(@user)
    TournamentParticipation.create!(account: @account, tournament: @tournament, role: "player")

    get "/api/v1/tournaments", params: { mine: "1" }

    assert_response :success
    assert_equal [ @tournament.id ], json["tournaments"].map { |t| t["id"] }
  end

  test "organisation_ids filters the directory by any selected organisation" do
    other_organisation = Organisation.create!(name: "Other Tournament Organisation", acronym: "OTO")
    other_tournament = Tournament.create!(
      name: "Other Organisation Open",
      organisation: other_organisation,
      created_by_account: @account,
      scope: "club",
      division_scheme: "letter",
      publication_state: "active",
      starts_at: 3.days.from_now,
      ends_at: 4.days.from_now,
      timezone: "UTC",
      all_day: false
    )

    get "/api/v1/tournaments", params: { organisation_ids: [ @organisation.id, other_organisation.id ] }

    assert_response :success
    assert_equal [ @tournament.id, other_tournament.id ].sort, json["tournaments"].map { |t| t["id"] }.sort
  end

  # --- management authorization (regression: admin-only lifecycle) -----------

  test "admin can cancel a tournament" do
    sign_in_as(@admin)

    post_json "/api/v1/tournaments/#{@tournament.id}/cancel", {}

    assert_response :success
    assert_equal "cancelled", json["publication_state"]
    assert_equal "cancelled", @tournament.reload.publication_state
  end

  test "a non-admin member cannot cancel a tournament" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/cancel", {}

    assert_response :forbidden
    assert_equal "active", @tournament.reload.publication_state
  end

  # --- payload permission flag ------------------------------------------------

  test "detail stamps can_edit for the organisation's owner" do
    sign_in_as(accounts(:two).user)

    get "/api/v1/tournaments/#{@tournament.id}"

    assert_response :success
    assert_equal true, json["organisation"]["can_edit"]
  end

  test "detail stamps can_edit for the account that created the tournament" do
    sign_in_as(@user)

    get "/api/v1/tournaments/#{@tournament.id}"

    assert_response :success
    assert_equal true, json["organisation"]["can_edit"]
  end

  test "detail denies can_edit to an unrelated signed-in account" do
    sign_in_as(accounts(:three).user)

    get "/api/v1/tournaments/#{@tournament.id}"

    assert_response :success
    assert_equal false, json["organisation"]["can_edit"]
  end

  # --- follow (the watching-list bookmark) ------------------------------------

  test "unauthenticated follow is rejected" do
    post_json "/api/v1/tournaments/#{@tournament.id}/follow", {}

    assert_response :unauthorized
  end

  test "following records the bookmark and is idempotent" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/follow", {}
    assert_response :success
    assert_equal true, json["my_following"]
    assert_equal 1, TournamentFollow.where(account: @account, tournament: @tournament).count

    post_json "/api/v1/tournaments/#{@tournament.id}/follow", {}
    assert_response :success
    assert_equal 1, TournamentFollow.where(account: @account, tournament: @tournament).count
  end

  test "unfollowing removes the bookmark and is idempotent" do
    sign_in_as(@user)
    TournamentFollow.create!(account: @account, tournament: @tournament)

    delete_json "/api/v1/tournaments/#{@tournament.id}/follow"
    assert_response :no_content
    assert_nil TournamentFollow.find_by(account: @account, tournament: @tournament)

    delete_json "/api/v1/tournaments/#{@tournament.id}/follow"
    assert_response :no_content
  end

  # --- relationship filters ----------------------------------------------------

  test "relationship=participating returns tournaments the caller participates in" do
    sign_in_as(@user)
    TournamentParticipation.create!(account: @account, tournament: @tournament, role: "player")

    get "/api/v1/tournaments", params: { relationship: ["participating"] }

    assert_response :success
    assert_equal [ @tournament.id ], json["tournaments"].map { |t| t["id"] }
  end

  test "relationship=created returns tournaments the caller created" do
    sign_in_as(@user) # @tournament was created by @account

    get "/api/v1/tournaments", params: { relationship: ["created"] }

    assert_response :success
    assert_equal [ @tournament.id ], json["tournaments"].map { |t| t["id"] }
  end

  test "relationship=following returns tournaments the caller follows" do
    sign_in_as(@user)
    TournamentFollow.create!(account: @account, tournament: @tournament)

    get "/api/v1/tournaments", params: { relationship: ["following"] }

    assert_response :success
    assert_equal [ @tournament.id ], json["tournaments"].map { |t| t["id"] }
  end

  test "relationship kinds are OR-combined" do
    sign_in_as(@user)
    followed = Tournament.create!(
      name: "Followed Open",
      organisation: @organisation,
      created_by_account: accounts(:two),
      scope: "club",
      division_scheme: "letter",
      publication_state: "active",
      starts_at: 5.days.from_now,
      ends_at: 6.days.from_now,
      timezone: "UTC",
      all_day: false
    )
    TournamentFollow.create!(account: @account, tournament: followed)

    get "/api/v1/tournaments", params: { relationship: ["created", "following"] }

    assert_response :success
    assert_equal [ @tournament.id, followed.id ].sort, json["tournaments"].map { |t| t["id"] }.sort
  end

  test "relationship requires authentication" do
    get "/api/v1/tournaments", params: { relationship: ["following"] }

    assert_response :unauthorized
  end
end
