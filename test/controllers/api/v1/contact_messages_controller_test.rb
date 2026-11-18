require "test_helper"

# Request tests for the public contact endpoint (IDENTITY-259).
#
# Pinned here: anonymous submissions work, the public response leaks nothing,
# management fields are unreachable, the honeypot is discarded quietly, and the
# Turnstile decisions fail closed.
class Api::V1::ContactMessagesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  VALID_ENQUIRY = {
    name: "Jordan Smith",
    email: "jordan@example.com",
    contact_type: "coaching",
    subject: "Question about coaching sessions",
    message: "I would like more information about the available sessions."
  }.freeze

  setup do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    # No Turnstile key in the test suite: the verifier reports :disabled, which
    # is exactly the local-development behaviour.
    @previous_secret = ENV.delete("TURNSTILE_SECRET_KEY")
  end

  teardown do
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear
    ENV["TURNSTILE_SECRET_KEY"] = @previous_secret unless @previous_secret.nil?
  end

  def payload(overrides = {})
    { contact_message: VALID_ENQUIRY.merge(overrides) }
  end

  def submit(overrides = {})
    post "/api/v1/contact_messages", params: payload(overrides), as: :json
  end

  # Minitest 6 no longer ships `minitest/mock`, so the verifier seam is a
  # temporary singleton-method swap: the controller calls the real class, and the
  # test controls the decision it returns.
  def with_turnstile_result(result)
    singleton = TurnstileVerifier.singleton_class
    singleton.alias_method(:__original_verify, :verify)
    singleton.define_method(:verify) { |**| result }
    yield
  ensure
    singleton.alias_method(:verify, :__original_verify)
    singleton.remove_method(:__original_verify)
  end

  test "an anonymous visitor can submit a valid enquiry" do
    assert_difference -> { ContactMessage.count }, 1 do
      submit
    end

    assert_response :created
    assert_equal "Your message has been received.", json_body["message"]

    message = ContactMessage.order(:id).last
    assert_equal "jordan@example.com", message.email
    assert_equal "coaching", message.contact_type
    assert_equal "unread", message.status
    assert_nil message.read_at
  end

  test "delivery is enqueued for the stored message" do
    assert_enqueued_with(job: ContactMessageDeliveryJob) { submit }

    assert_response :created
  end

  test "the public response exposes no internal data" do
    submit

    assert_equal [ "message" ], json_body.keys
    refute_includes response.body, "status"
    refute_includes response.body, ContactMessage::CONTACT_TYPES.first
  end

  test "an invalid email address is rejected" do
    assert_no_difference -> { ContactMessage.count } do
      submit(email: "not-an-email")
    end

    assert_response :unprocessable_entity
    assert json_body["errors"].any? { |error| error.start_with?("Email") }
  end

  test "an unsupported contact type is rejected" do
    assert_no_difference -> { ContactMessage.count } do
      submit(contact_type: "sales_pitch")
    end

    assert_response :unprocessable_entity
    assert_includes json_body["errors"], "Contact type is not included in the list"
  end

  test "blank required fields are rejected" do
    assert_no_difference -> { ContactMessage.count } do
      submit(name: "", subject: "   ", message: "")
    end

    assert_response :unprocessable_entity
    errors = json_body["errors"]
    assert_includes errors, "Name can't be blank"
    assert_includes errors, "Subject can't be blank"
    assert_includes errors, "Message can't be blank"
  end

  test "public clients cannot set management fields" do
    submit(status: "read", read_at: Time.current, archived_at: Time.current,
           emailed_at: Time.current, notified_at: Time.current, email_delivery_status: "sent")

    assert_response :created

    message = ContactMessage.order(:id).last
    assert_equal "unread", message.status
    assert_nil message.read_at
    assert_nil message.archived_at
    assert_nil message.emailed_at
    assert_nil message.notified_at
  end

  test "a request without a contact_message payload is rejected" do
    post "/api/v1/contact_messages", params: {}, as: :json

    assert_response :bad_request
  end

  test "a filled honeypot is discarded quietly" do
    assert_no_difference -> { ContactMessage.count } do
      assert_no_enqueued_jobs do
        submit(website: "https://spam.example")
      end
    end

    # Indistinguishable from success: a bot learns nothing from the response.
    assert_response :created
    assert_equal "Your message has been received.", json_body["message"]
  end

  test "options lists every supported category with a human label" do
    get "/api/v1/contact_messages/options"

    assert_response :success
    types = json_body["contact_types"]
    assert_equal ContactMessage::CONTACT_TYPES, types.map { |type| type["value"] }
    assert_equal "General enquiry", types.first["label"]
  end

  # --- Turnstile --------------------------------------------------------------

  test "a rejected turnstile token blocks the submission" do
    result = TurnstileVerifier::Result.new(status: :invalid, errors: [ "invalid-input-response" ])

    with_turnstile_result(result) do
      assert_no_difference -> { ContactMessage.count } do
        submit(turnstile_token: "bad-token")
      end
    end

    assert_response :unprocessable_entity
    assert_match(/could not verify/i, json_body["errors"].first)
    refute_includes response.body, "invalid-input-response"
  end

  test "an unavailable verifier fails closed" do
    result = TurnstileVerifier::Result.new(status: :unavailable, errors: [ "verification unavailable" ])

    with_turnstile_result(result) do
      assert_no_difference -> { ContactMessage.count } do
        submit(turnstile_token: "any-token")
      end
    end

    assert_response :service_unavailable
    assert_match(/temporarily unavailable/i, json_body["error"])
  end

  test "a verified token allows the submission" do
    result = TurnstileVerifier::Result.new(status: :valid, errors: [])

    with_turnstile_result(result) do
      assert_difference -> { ContactMessage.count }, 1 do
        submit(turnstile_token: "good-token")
      end
    end

    assert_response :created
  end
end
