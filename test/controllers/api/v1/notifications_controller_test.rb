require "test_helper"

# Request tests for the notifications API.
#
# Two things matter here and are pinned explicitly: the endpoints are
# authenticated, and every read/write is scoped to the caller's own account, so
# one account can never see or mark another account's notifications.
class Api::V1::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:five)          # account one (John Smith)
    @other = users(:six)           # account two (Maria Silva)
    @account = accounts(:one)
    @other_account = accounts(:two)

    @mine = @account.notifications.create!(
      event_type: "training.cancelled",
      event_key: "training:1:cancelled-1",
      title: "Training cancelled",
      message: "Serve Reception Training has been cancelled."
    )
    @theirs = @other_account.notifications.create!(
      event_type: "training.cancelled",
      event_key: "training:1:cancelled-1",
      title: "Not yours",
      message: "Not yours"
    )
  end

  def json
    JSON.parse(response.body)
  end

  # --- authentication ---------------------------------------------------------

  test "index requires authentication" do
    get "/api/v1/notifications"
    assert_response :unauthorized
  end

  test "unread_count requires authentication" do
    get "/api/v1/notifications/unread_count"
    assert_response :unauthorized
  end

  # --- read -------------------------------------------------------------------

  test "index returns only the caller's notifications" do
    sign_in_as(@owner)
    get "/api/v1/notifications"

    assert_response :success
    ids = json["data"].map { |row| row["id"] }
    assert_equal [ @mine.id ], ids
    assert_equal 1, json["meta"]["total"]
  end

  test "index can filter to unread only" do
    @mine.mark_read!
    sign_in_as(@owner)

    get "/api/v1/notifications", params: { unread: "true" }
    assert_response :success
    assert_empty json["data"]

    get "/api/v1/notifications"
    assert_equal [ @mine.id ], json["data"].map { |row| row["id"] }
  end

  test "index can filter by event type" do
    other_event = @account.notifications.create!(
      event_type: "membership.approved", event_key: "org:1:membership:1:approved",
      title: "Membership approved", message: "Approved"
    )
    sign_in_as(@owner)

    get "/api/v1/notifications", params: { event_type: "membership.approved" }

    assert_equal [ other_event.id ], json["data"].map { |row| row["id"] }
  end

  test "unread_count counts only the caller's unread rows" do
    @account.notifications.create!(
      event_type: "training.invited", event_key: "training:1:participants-1",
      title: "Invitation", message: "Invitation"
    )
    sign_in_as(@owner)

    get "/api/v1/notifications/unread_count"

    assert_response :success
    assert_equal 2, json["unread_count"]
  end

  # --- write ------------------------------------------------------------------

  test "mark_read marks the caller's own notification" do
    sign_in_as(@owner)

    patch "/api/v1/notifications/#{@mine.id}/mark_read"

    assert_response :success
    assert json["read"]
    assert @mine.reload.read?
  end

  test "mark_read cannot reach another account's notification" do
    sign_in_as(@owner)

    patch "/api/v1/notifications/#{@theirs.id}/mark_read"

    assert_response :not_found
    assert_not @theirs.reload.read?
  end

  test "mark_all_read only touches the caller's unread rows" do
    sign_in_as(@owner)

    patch "/api/v1/notifications/mark_all_read"

    assert_response :success
    assert_equal 1, json["marked"]
    assert @mine.reload.read?
    assert_not @theirs.reload.read?
  end
end
