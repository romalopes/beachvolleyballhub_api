require "test_helper"

# Conversation API (IDENTITY-265): submitters and the team exchange messages,
# each message notifies the other side and queues exactly one email.
class Api::V1::AnalysisRequestMessagesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @account = accounts(:one)
    @user = @account.user
    @session, @headers = sign_in_with_api_token(@user)
    @analysis_request = analysis_requests(:one)
    @crew = accounts(:admin) # users(:two) is an admin

    @previous_recipients = ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"]
    ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"] = "crew@bvb.test"
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    if @previous_recipients.nil?
      ENV.delete("ANALYSIS_REQUEST_NOTIFICATION_EMAILS")
    else
      ENV["ANALYSIS_REQUEST_NOTIFICATION_EMAILS"] = @previous_recipients
    end
  end

  test "the submitter posts a message, notifying and emailing the crew" do
    assert_difference -> { @analysis_request.analysis_request_messages.count }, 1 do
      assert_enqueued_with(job: AnalysisRequestMessageEmailJob) do
        post api_v1_analysis_request_analysis_request_messages_path(@analysis_request),
             params: { body: "Any update on the report?" }, headers: @headers, as: :json
      end
    end

    assert_response :created
    body = response.parsed_body["message"]
    assert body["from_submitter"]
    assert_equal @account.full_name, body["author"]["name"]

    notification = Notification.where(account: @crew).order(:created_at).last
    assert notification, "expected the crew to be notified"
    assert_equal "analysis_request.message", notification.event_type
  end

  test "staff reply notifies and emails the submitter" do
    _session, admin_headers = sign_in_with_api_token(users(:two))

    assert_enqueued_with(job: AnalysisRequestMessageEmailJob) do
      post api_v1_analysis_request_analysis_request_messages_path(@analysis_request),
           params: { body: "We are working on it today." }, headers: admin_headers, as: :json
    end

    assert_response :created
    message = @analysis_request.analysis_request_messages.order(:created_at).last
    assert_not message.from_submitter
    assert_equal accounts(:admin), message.account

    notification = Notification.where(account: @account).order(:created_at).last
    assert notification, "expected the submitter to be notified"
    assert_equal "New message from the team", notification.title
  end

  test "internal staff messages are not emailed or notified" do
    _session, admin_headers = sign_in_with_api_token(users(:two))

    assert_no_enqueued_jobs only: AnalysisRequestMessageEmailJob do
      assert_no_difference -> { Notification.count } do
        post api_v1_analysis_request_analysis_request_messages_path(@analysis_request),
             params: { body: "Internal only", internal: true },
             headers: admin_headers, as: :json
      end
    end

    assert_response :created
    assert response.parsed_body["message"]["internal"]
  end

  test "an unrelated member cannot post" do
    _session, other_headers = sign_in_with_api_token(users(:three))

    post api_v1_analysis_request_analysis_request_messages_path(@analysis_request),
         params: { body: "Hello" }, headers: other_headers, as: :json

    assert_response :forbidden
  end

  test "blank bodies are rejected" do
    post api_v1_analysis_request_analysis_request_messages_path(@analysis_request),
         params: { body: "   " }, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "the guest token can post as the submitter" do
    guest_request = analysis_requests(:guest_one)

    assert_enqueued_with(job: AnalysisRequestMessageEmailJob) do
      post api_v1_guest_analysis_request_messages_path(guest_request.guest_access_token),
           params: { body: "Here is the second video." }, as: :json
    end

    assert_response :created
    message = guest_request.analysis_request_messages.order(:created_at).last
    assert message.from_submitter
    assert_not message.internal
    assert_nil message.account
  end

  test "an unknown guest token is a 404" do
    post api_v1_guest_analysis_request_messages_path("nope"),
         params: { body: "Hello" }, as: :json

    assert_response :not_found
  end

  test "the owner never sees internal messages" do
    @analysis_request.analysis_request_messages.create!(
      body: "Internal note", internal: true, from_submitter: false, account: accounts(:admin)
    )
    @analysis_request.analysis_request_messages.create!(
      body: "Visible reply", internal: false, from_submitter: false, account: accounts(:admin)
    )

    get api_v1_analysis_request_analysis_request_messages_path(@analysis_request), headers: @headers

    bodies = response.parsed_body["data"].map { |message| message["body"] }
    assert_equal [ "Visible reply" ], bodies
  end

  test "staff see internal messages in the conversation" do
    _session, admin_headers = sign_in_with_api_token(users(:two))
    @analysis_request.analysis_request_messages.create!(
      body: "Internal note", internal: true, from_submitter: false, account: @crew
    )

    get api_v1_analysis_request_analysis_request_messages_path(@analysis_request), headers: admin_headers

    bodies = response.parsed_body["data"].map { |message| message["body"] }
    assert_includes bodies, "Internal note"
  end
end
