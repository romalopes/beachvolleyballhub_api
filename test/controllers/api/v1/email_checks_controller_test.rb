require "test_helper"

# The public "is this email registered?" probe (IDENTITY-265) that drives the
# hire-analysis login / create-account / guest prompt.
class Api::V1::EmailChecksControllerTest < ActionDispatch::IntegrationTest
  test "reports a registered email" do
    get api_v1_email_check_path, params: { email: "five@example.com" }, as: :json

    assert_response :ok
    assert_equal true, response.parsed_body["registered"]
    assert_equal "five@example.com", response.parsed_body["email_address"]
  end

  test "reports an unknown email" do
    get api_v1_email_check_path, params: { email: "stranger@example.com" }, as: :json

    assert_response :ok
    assert_equal false, response.parsed_body["registered"]
  end

  test "normalises the email before matching" do
    get api_v1_email_check_path, params: { email: "  FIVE@example.com " }, as: :json

    assert_response :ok
    assert_equal true, response.parsed_body["registered"]
    assert_equal "five@example.com", response.parsed_body["email_address"]
  end

  test "requires an email" do
    get api_v1_email_check_path, as: :json

    assert_response :bad_request
  end

  test "reveals nothing without an email parameter beyond the error" do
    get api_v1_email_check_path, as: :json

    assert_equal({ "error" => "Email is required." }, response.parsed_body)
  end
end
