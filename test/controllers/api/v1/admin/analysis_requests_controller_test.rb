require "test_helper"

class Api::V1::Admin::AnalysisRequestsControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @account = accounts(:one)
    @user = @account.user
    @session, @headers = sign_in_with_api_token(@user)
  end

  test "members cannot list the staff inbox" do
    get api_v1_admin_analysis_requests_path, headers: @headers

    assert_response :forbidden
  end

  test "staff see submitter details alongside each request" do
    @user.add_role(:admin)

    get api_v1_admin_analysis_requests_path, headers: @headers

    assert_response :success
    guest = response.parsed_body["data"].find { |row| row["reference"] == "ANL-2026-0002" }
    assert_equal "Jane Guest", guest["guest_name"]
    assert_equal "jane@example.com", guest["submitter_email"]
  end

  test "the reference search narrows the inbox" do
    @user.add_role(:curator)

    get api_v1_admin_analysis_requests_path, params: { q: "0002" }, headers: @headers

    assert_response :success
    references = response.parsed_body["data"].map { |row| row["reference"] }
    assert_equal [ "ANL-2026-0002" ], references
  end

  test "staff detail includes internal notes" do
    @user.add_role(:admin)
    request = analysis_requests(:guest_one)
    request.analysis_request_internal_notes.create!(
      body: "Chase the footage", account: @account
    )

    get api_v1_admin_analysis_request_path(request), headers: @headers

    assert_response :success
    notes = response.parsed_body["analysis_request"]["internal_notes"]
    assert_equal [ "Chase the footage" ], notes.map { |note| note["body"] }
  end
end
