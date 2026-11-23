require "test_helper"

class Api::V1::AnalysisRequestsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    # accounts(:one) belongs to users(:five); users(:one) is deliberately
    # account-less in the fixtures.
    @account = accounts(:one)
    @user = @account.user
    @session, @headers = sign_in_with_api_token(@user)
  end

  # --- create ---------------------------------------------------------------

  test "guest create stores the request and returns a guest access token" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: {
        title: "Serve analysis",
        description: "Please review my jump serve",
        guest_name: "Jane Guest",
        guest_email: "jane@example.com"
      }
    }, as: :json

    assert_response :created
    body = response.parsed_body
    assert_match(/\AANL-\d{4}-\d{4}\z/, body["analysis_request"]["reference"])
    assert body["analysis_request"]["guest_access_token"].present?
    assert_equal "submitted", body["analysis_request"]["workflow_status"]
    # Crew + submitter emails are queued, never sent on the request thread.
    assert_enqueued_jobs 1, only: AnalysisRequestSubmissionJob
  end

  test "guest create with an external video URL is accepted" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: {
        title: "External video request",
        description: "YouTube link",
        guest_name: "Jane Guest",
        guest_email: "jane@example.com",
        analysis_request_videos_attributes: {
          "0" => {
            source_type: "external",
            external_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
          }
        }
      }
    }, as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal 1, body["analysis_request"]["videos"].length
    assert_equal "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                 body["analysis_request"]["videos"].first["external_url"]
  end

  test "guest create tolerates legacy clients that send a URL in video_id" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: {
        title: "Legacy payload",
        guest_name: "Jane Guest",
        guest_email: "jane@example.com",
        analysis_request_videos_attributes: {
          "0" => {
            source_type: "external",
            video_id: "https://www.youtube.com/watch?v=w8irm9jy34U"
          }
        }
      }
    }, as: :json

    assert_response :created
    video = response.parsed_body["analysis_request"]["videos"].first
    assert_equal "https://www.youtube.com/watch?v=w8irm9jy34U", video["external_url"]
    assert_nil video["video_id"]
  end

  test "guest create without a name is rejected" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: { title: "No name", guest_email: "jane@example.com" }
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "authenticated create links the request to the caller's account" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: { title: "My analysis", description: "Review my game" }
    }, headers: @headers, as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal @account.id, body["analysis_request"]["account_id"]
    assert_nil body["analysis_request"]["guest_name"]
  end

  test "create with an unknown package key is rejected" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: { title: "Bad package", package_key: "does_not_exist" }
    }, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  # --- index / show ---------------------------------------------------------

  test "index returns only the caller's own requests" do
    @account.analysis_requests.create!(title: "Mine", guest_name: "Me", guest_email: "me@example.com")
    accounts(:two).analysis_requests.create!(title: "Theirs", guest_name: "Them", guest_email: "them@example.com")

    get api_v1_analysis_requests_path, headers: @headers

    assert_response :success
    titles = response.parsed_body["data"].map { |row| row["title"] }
    assert_includes titles, "Mine"
    assert_not_includes titles, "Theirs"
  end

  test "index lets an administrator see every request" do
    @user.add_role(:admin)
    AnalysisRequest.create!(title: "Guest one", guest_name: "A", guest_email: "a@example.com")

    get api_v1_analysis_requests_path, headers: @headers

    assert_response :success
    assert_operator response.parsed_body["data"].length, :>=, 2
  end

  test "show lets the owner read the request" do
    request = @account.analysis_requests.create!(title: "Mine", guest_name: "Me", guest_email: "me@example.com")

    get api_v1_analysis_request_path(request), headers: @headers

    assert_response :success
    assert_equal request.id, response.parsed_body["analysis_request"]["id"]
  end

  test "show hides another account's request" do
    request = accounts(:two).analysis_requests.create!(title: "Theirs", guest_name: "Them", guest_email: "them@example.com")

    get api_v1_analysis_request_path(request), headers: @headers

    assert_response :not_found
  end

  test "show requires authentication" do
    request = @account.analysis_requests.create!(title: "Mine", guest_name: "Me", guest_email: "me@example.com")

    get api_v1_analysis_request_path(request)

    assert_response :unauthorized
  end

  # --- guest access ---------------------------------------------------------

  test "guest access returns the request for a valid token" do
    request = AnalysisRequest.create!(title: "Guest request", guest_name: "Jane", guest_email: "jane@example.com")

    get guest_access_api_v1_analysis_requests_path(token: request.guest_access_token)

    assert_response :success
    body = response.parsed_body
    assert_equal request.id, body["analysis_request"]["id"]
    assert_equal "Jane", body["analysis_request"]["guest_name"]
  end

  test "guest access with an unknown token is not found" do
    get guest_access_api_v1_analysis_requests_path(token: "nope")

    assert_response :not_found
  end

  test "guest access shows the conversation but never internal notes" do
    request = AnalysisRequest.create!(title: "Guest request", guest_name: "Jane", guest_email: "jane@example.com")
    request.analysis_request_messages.create!(body: "Visible reply", from_submitter: false)
    request.analysis_request_messages.create!(body: "Staff only note", from_submitter: false, internal: true)

    get guest_access_api_v1_analysis_requests_path(token: request.guest_access_token)

    assert_response :success
    bodies = response.parsed_body["analysis_request"]["messages"].map { |m| m["body"] }
    assert_includes bodies, "Visible reply"
    assert_not_includes bodies, "Staff only note"
  end

  # --- update / destroy -----------------------------------------------------

  test "update lets the owner change the title while submitted" do
    request = @account.analysis_requests.create!(title: "Original", guest_name: "Me", guest_email: "me@example.com")

    patch api_v1_analysis_request_path(request), params: {
      analysis_request: { title: "Updated" }
    }, headers: @headers, as: :json

    assert_response :success
    assert_equal "Updated", response.parsed_body["analysis_request"]["title"]
  end

  test "update is refused once the request is accepted" do
    request = @account.analysis_requests.create!(title: "Original", guest_name: "Me", guest_email: "me@example.com")
    request.accept!(price_cents: 4900)

    patch api_v1_analysis_request_path(request), params: {
      analysis_request: { title: "Updated" }
    }, headers: @headers, as: :json

    assert_response :forbidden
  end

  test "destroy is staff-only" do
    request = @account.analysis_requests.create!(title: "Mine", guest_name: "Me", guest_email: "me@example.com")

    delete api_v1_analysis_request_path(request), headers: @headers
    assert_response :forbidden

    @user.add_role(:admin)
    delete api_v1_analysis_request_path(request), headers: @headers
    assert_response :no_content
  end

  # --- pagination -----------------------------------------------------------

  test "index paginates" do
    25.times { |i| @account.analysis_requests.create!(title: "Request #{i}", guest_name: "Me", guest_email: "me@example.com") }

    get api_v1_analysis_requests_path, params: { page: 1, per: 10 }, headers: @headers

    assert_response :success
    body = response.parsed_body
    assert_equal 10, body["data"].length
    assert_equal 3, body["meta"]["total_pages"]
  end
end