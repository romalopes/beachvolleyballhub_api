require "test_helper"

# Request tests for the internal Contact Messages inbox (IDENTITY-259).
#
# The authorization matrix is the point of this file: only the platform-wide
# Admin and Curator roles may read a public enquiry. Coaches, players/readers and
# anonymous callers are denied, and the inbox never exposes a body in the list.
class Api::V1::Admin::ContactMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)     # coach + admin
    @curator = users(:four)  # curator (platform-wide)
    @coach = users(:three)   # coach only
    @player = users(:one)    # player only
  end

  def data
    json_body["data"]
  end

  def ids
    data.map { |row| row["id"] }
  end

  # --- authorization ----------------------------------------------------------

  test "anonymous callers are rejected" do
    get "/api/v1/admin/contact_messages"
    assert_response :unauthorized

    # Read-by-id denials render 404 app-wide ("hidden record looks missing"), so
    # an unauthorised caller cannot probe which ids exist.
    get "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}"
    assert_response :not_found

    patch "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}",
          params: { contact_message: { status: "read" } }, as: :json
    assert_response :unauthorized
  end

  test "players and coaches cannot read the platform inbox" do
    [ @player, @coach ].each do |user|
      sign_in_as(user)

      get "/api/v1/admin/contact_messages"
      assert_response :forbidden

      get "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}"
      assert_response :not_found

      patch "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}",
            params: { contact_message: { status: "archived" } }, as: :json
      assert_response :forbidden

      assert_equal "unread", contact_messages(:unread_general).reload.status
    end
  end

  test "a platform curator can read and update messages" do
    sign_in_as(@curator)

    get "/api/v1/admin/contact_messages"
    assert_response :success

    get "/api/v1/admin/contact_messages/#{contact_messages(:read_coaching).id}"
    assert_response :success

    patch "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}",
          params: { contact_message: { status: "read" } }, as: :json
    assert_response :success
  end

  test "an admin can read the inbox" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages"
    assert_response :success
    assert_equal 3, json_body["meta"]["total"]
  end

  # --- index ------------------------------------------------------------------

  test "the list is newest first and omits the message body" do
    sign_in_as(@admin)
    get "/api/v1/admin/contact_messages"

    assert_response :success
    assert_equal [ contact_messages(:archived_feedback).id,
                   contact_messages(:read_coaching).id,
                   contact_messages(:unread_general).id ], ids
    refute data.first.key?("message")
    assert_equal "Suggestion for the calendar", data.first["subject"]
  end

  test "the list filters by status" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { status: "unread" }
    assert_response :success
    assert_equal [ contact_messages(:unread_general).id ], ids

    get "/api/v1/admin/contact_messages", params: { status: "read" }
    assert_equal [ contact_messages(:read_coaching).id ], ids

    get "/api/v1/admin/contact_messages", params: { status: "archived" }
    assert_equal [ contact_messages(:archived_feedback).id ], ids

    get "/api/v1/admin/contact_messages", params: { status: "all" }
    assert_equal 3, ids.size
  end

  test "an unsupported status filter is ignored rather than trusted" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { status: "deleted" }

    assert_response :success
    assert_equal 3, ids.size
  end

  test "the list filters by contact type" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { contact_type: "coaching" }

    assert_response :success
    assert_equal [ contact_messages(:read_coaching).id ], ids
  end

  test "the list searches name, email and subject" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { search: "jordan" }
    assert_equal [ contact_messages(:unread_general).id ], ids

    get "/api/v1/admin/contact_messages", params: { search: "PRIYA@EXAMPLE.COM" }
    assert_equal [ contact_messages(:read_coaching).id ], ids

    get "/api/v1/admin/contact_messages", params: { search: "calendar" }
    assert_equal [ contact_messages(:archived_feedback).id ], ids
  end

  test "search and filters combine" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { search: "e", status: "archived" }

    assert_response :success
    assert_equal [ contact_messages(:archived_feedback).id ], ids
  end

  test "the list paginates and reports metadata" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { page: 2, per_page: 1 }

    assert_response :success
    assert_equal 1, data.size
    assert_equal 2, json_body["meta"]["page"]
    assert_equal 3, json_body["meta"]["total"]
    assert_equal 3, json_body["meta"]["total_pages"]
  end

  test "per_page is clamped to the supported maximum" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { per_page: 10_000 }

    assert_response :success
    assert_equal 100, json_body["meta"]["per_page"]
  end

  test "an unsupported sort column falls back to created_at" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages", params: { sort: "message; DROP TABLE contact_messages" }

    assert_response :success
    assert_equal contact_messages(:archived_feedback).id, ids.first
    assert ContactMessage.table_exists?
  end

  test "status counts are returned for the inbox tabs" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages"

    assert_response :success
    assert_equal({ "all" => 3, "unread" => 1, "read" => 1, "archived" => 1 }, json_body["counts"])
  end

  test "the unread count excludes archived messages" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages/unread_count"

    assert_response :success
    assert_equal 1, json_body["unread_count"]
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  # --- show -------------------------------------------------------------------

  test "the detail includes the plain-text body" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}"

    assert_response :success
    assert_equal "I would like more information about the available sessions.", json_body["data"]["message"]
    assert_equal "General enquiry", json_body["data"]["contact_type_label"]
  end

  test "opening a message does not change its status" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages/#{contact_messages(:unread_general).id}"

    assert_equal "unread", contact_messages(:unread_general).reload.status
  end

  test "an unknown message is a 404" do
    sign_in_as(@admin)

    get "/api/v1/admin/contact_messages/0"

    assert_response :not_found
    assert_equal "Contact message not found", json_body["error"]
  end

  # --- update -----------------------------------------------------------------

  test "marking read sets read_at" do
    sign_in_as(@curator)
    message = contact_messages(:unread_general)

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: { contact_message: { status: "read" } }, as: :json

    assert_response :success
    message.reload
    assert_equal "read", message.status
    assert_not_nil message.read_at
    assert_equal "read", json_body["data"]["status"]
  end

  test "marking unread clears read_at" do
    sign_in_as(@curator)
    message = contact_messages(:read_coaching)

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: { contact_message: { status: "unread" } }, as: :json

    assert_response :success
    message.reload
    assert_equal "unread", message.status
    assert_nil message.read_at
  end

  test "archiving records archived_at and unarchiving restores the inbox" do
    sign_in_as(@curator)
    message = contact_messages(:unread_general)

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: { contact_message: { status: "archived" } }, as: :json
    assert_response :success
    assert_not_nil message.reload.archived_at

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: { contact_message: { status: "read" } }, as: :json
    assert_response :success
    assert_nil message.reload.archived_at
    assert_equal "read", message.status
  end

  test "status changes are idempotent" do
    sign_in_as(@curator)
    message = contact_messages(:read_coaching)
    read_at = message.read_at

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: { contact_message: { status: "read" } }, as: :json

    assert_response :success
    assert_equal read_at, message.reload.read_at
  end

  test "an unsupported status is rejected" do
    sign_in_as(@curator)
    message = contact_messages(:unread_general)

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: { contact_message: { status: "deleted" } }, as: :json

    assert_response :unprocessable_entity
    assert_match(/Status must be one of/, json_body["errors"].first)
    assert_equal "unread", message.reload.status
  end

  test "only the status is writable" do
    sign_in_as(@curator)
    message = contact_messages(:unread_general)

    patch "/api/v1/admin/contact_messages/#{message.id}",
          params: {
            contact_message: {
              status: "read",
              name: "Someone Else",
              email: "someone@else.example",
              subject: "Rewritten",
              message: "Rewritten body",
              read_at: 10.years.ago
            }
          }, as: :json

    assert_response :success
    message.reload
    assert_equal "Jordan Smith", message.name
    assert_equal "jordan@example.com", message.email
    assert_equal "Question about coaching sessions", message.subject
    assert_equal "I would like more information about the available sessions.", message.message
    assert message.read_at > 1.minute.ago
  end
end
