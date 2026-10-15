require "test_helper"

# Request tests for the ordered watch-link management surface (Phase 8):
# add/reorder/remove links, gated on tournament-management authority.
class Api::V1::TournamentWatchLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organisation = organisations(:sydney_club)
    @account = accounts(:one)
    @user = @account.user          # active club member, not a manager
    @admin = users(:two)           # carries the admin role

    @tournament = Tournament.create!(
      name: "Watch Link Tournament",
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

  test "admin can add a watch link" do
    sign_in_as(@admin)

    post_json "/api/v1/tournaments/#{@tournament.id}/watch_links",
              watch_link: { name: "Livestream", url: "https://example.com/stream", provider: "youtube", starts_at: Time.current }

    assert_response :created
    assert_equal "Livestream", json["name"]
    assert_equal "https://example.com/stream", json["url"]
  end

  test "admin can reorder watch links" do
    sign_in_as(@admin)

    post_json "/api/v1/tournaments/#{@tournament.id}/watch_links",
              watch_link: { name: "First", url: "https://example.com/1", provider: "youtube", starts_at: Time.current }
    first = json
    post_json "/api/v1/tournaments/#{@tournament.id}/watch_links",
              watch_link: { name: "Second", url: "https://example.com/2", provider: "youtube", starts_at: Time.current }

    patch_json "/api/v1/tournaments/#{@tournament.id}/watch_links/#{first["id"]}",
               watch_link: { position: 5 }

    assert_response :success
    assert_equal 5, json["position"]
  end

  test "admin can remove a watch link" do
    sign_in_as(@admin)

    post_json "/api/v1/tournaments/#{@tournament.id}/watch_links",
              watch_link: { name: "Livestream", url: "https://example.com/stream", provider: "youtube", starts_at: Time.current }
    id = json["id"]

    delete_json "/api/v1/tournaments/#{@tournament.id}/watch_links/#{id}"

    assert_response :no_content
    assert_nil TournamentWatchLink.find_by(id: id)
  end

  test "a non-admin member cannot add a watch link" do
    sign_in_as(@user)

    post_json "/api/v1/tournaments/#{@tournament.id}/watch_links",
              watch_link: { name: "Livestream", url: "https://example.com/stream", provider: "youtube", starts_at: Time.current }

    assert_response :forbidden
  end
end
