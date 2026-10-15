require "test_helper"

# Request tests for the tournament division management surface (Phase 8):
# add/deactivate/remove divisions, gated on tournament-management authority.
class Api::V1::TournamentDivisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organisation = organisations(:sydney_club)
    @account = accounts(:one)
    @user = @account.user          # active club member, not a manager
    @admin = users(:two)           # carries the admin role

    @tournament = Tournament.create!(
      name: "Division Tournament",
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
  end

  def json = JSON.parse(response.body)

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def patch_json(path, payload)
    patch path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def delete_json(path)
    delete path, headers: { "Content-Type" => "application/json" }
  end

  test "admin can add a division" do
    sign_in_as(@admin)

    post_json "/api/v1/tournaments/#{@tournament.id}/divisions", division: { letter_level: "AA" }

    assert_response :created
    assert_equal "AA", json["letter_level"]
    assert_equal "AA", json["division_code"]
  end

  test "admin can deactivate a division when another stays active" do
    sign_in_as(@admin)

    patch_json "/api/v1/tournaments/#{@tournament.id}/divisions/#{@division_a.id}",
               division: { active: false }

    assert_response :success
    refute json["active"]
  end

  test "admin can delete an unreferenced division" do
    sign_in_as(@admin)

    delete_json "/api/v1/tournaments/#{@tournament.id}/divisions/#{@division_b.id}"

    assert_response :no_content
    assert_nil TournamentDivision.find_by(id: @division_b.id)
  end

  test "a non-admin member cannot add a division" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/divisions", division: { letter_level: "AA" }

    assert_response :forbidden
  end

  test "a scheme-mismatched division is rejected" do
    sign_in_as(@admin)

    post_json "/api/v1/tournaments/#{@tournament.id}/divisions", division: { division_number: 1 }

    assert_response :unprocessable_entity
  end
end
