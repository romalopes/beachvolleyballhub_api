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

  test "authenticated create links the submitter's existing player profile" do
    post api_v1_analysis_requests_path, params: {
      analysis_request: { title: "Profiled request", description: "Review my block" }
    }, headers: @headers, as: :json

    assert_response :created
    row = AnalysisRequest.find(response.parsed_body.dig("analysis_request", "id"))
    assert_equal player_profiles(:john_player).id, row.player_profile_id
  end

  test "authenticated create builds a player profile when the account has none" do
    user = users(:six)
    _session, headers = sign_in_with_api_token(user)

    assert_difference "PlayerProfile.count", 1 do
      post api_v1_analysis_requests_path, params: {
        analysis_request: { title: "First request", description: "Review my serve" }
      }, headers: headers, as: :json
    end

    assert_response :created
    row = AnalysisRequest.find(response.parsed_body.dig("analysis_request", "id"))
    profile = row.player_profile
    assert_equal user.account.id, profile.account_id
    assert_equal "six@example.com", profile.email
    assert_equal "active", profile.status
    assert profile.display_name.present?
  end

  test "authenticated create reuses one profile across requests" do
    2.times do |n|
      post api_v1_analysis_requests_path, params: {
        analysis_request: { title: "Repeat #{n}", description: "Same player" }
      }, headers: @headers, as: :json
      assert_response :created
    end

    rows = AnalysisRequest.order(:id).last(2)
    assert_equal player_profiles(:john_player).id, rows.first.player_profile_id
    assert_equal rows.first.player_profile_id, rows.second.player_profile_id
  end

  # --- assessment session deliverables ---------------------------------------

  test "staff can link an assessment session as a deliverable" do
    _session, headers = sign_in_with_api_token(users(:two)) # admin
    request_row = @account.analysis_requests.create!(title: "Linked deliverables", guest_name: "Me", guest_email: "me@example.com")

    assert_difference -> { request_row.reload.assessment_sessions.count }, 1 do
      post link_assessment_session_api_v1_analysis_request_path(request_row),
           params: { assessment_session_id: assessment_sessions(:draft_squad).id },
           headers: headers, as: :json
    end

    assert_response :success
    linked = response.parsed_body.dig("analysis_request", "assessment_sessions")
    assert_equal [assessment_sessions(:draft_squad).id], linked.map { |s| s["id"] }
    assert_equal "Tuesday squad screening", linked.first["title"]
    assert linked.first["status"].present?
  end

  test "linking the same session twice does not duplicate it" do
    _session, headers = sign_in_with_api_token(users(:two))
    request_row = @account.analysis_requests.create!(title: "Idempotent link", guest_name: "Me", guest_email: "me@example.com")
    request_row.assessment_sessions << assessment_sessions(:draft_squad)

    assert_no_difference -> { request_row.reload.assessment_sessions.count } do
      post link_assessment_session_api_v1_analysis_request_path(request_row),
           params: { assessment_session_id: assessment_sessions(:draft_squad).id },
           headers: headers, as: :json
    end
    assert_response :success
  end

  test "linking is forbidden for the submitter" do
    request_row = @account.analysis_requests.create!(title: "Owner link", guest_name: "Me", guest_email: "me@example.com")

    assert_no_difference -> { request_row.reload.assessment_sessions.count } do
      post link_assessment_session_api_v1_analysis_request_path(request_row),
           params: { assessment_session_id: assessment_sessions(:draft_squad).id },
           headers: @headers, as: :json
    end
    assert_response :forbidden
  end

  test "linking requires authentication" do
    request_row = @account.analysis_requests.create!(title: "Anon link", guest_name: "Me", guest_email: "me@example.com")

    post link_assessment_session_api_v1_analysis_request_path(request_row),
         params: { assessment_session_id: assessment_sessions(:draft_squad).id }, as: :json
    assert_response :unauthorized
  end

  test "linking an unknown session is a 404" do
    _session, headers = sign_in_with_api_token(users(:two))
    request_row = @account.analysis_requests.create!(title: "Unknown session", guest_name: "Me", guest_email: "me@example.com")

    post link_assessment_session_api_v1_analysis_request_path(request_row),
         params: { assessment_session_id: 0 }, headers: headers, as: :json
    assert_response :not_found
  end

  test "staff can unlink an assessment session" do
    _session, headers = sign_in_with_api_token(users(:two))
    request_row = @account.analysis_requests.create!(title: "Unlink me", guest_name: "Me", guest_email: "me@example.com")
    request_row.assessment_sessions << assessment_sessions(:draft_squad)

    assert_difference -> { request_row.reload.assessment_sessions.count }, -1 do
      delete assessment_session_api_v1_analysis_request_path(request_row, assessment_sessions(:draft_squad).id),
             headers: headers, as: :json
    end

    assert_response :success
    assert_empty response.parsed_body.dig("analysis_request", "assessment_sessions")
  end

  test "linked assessment sessions reach the guest payload" do
    _session, headers = sign_in_with_api_token(users(:two))
    # Guest requests carry the secure token; account-backed ones do not.
    request_row = AnalysisRequest.create!(title: "Guest deliverable", guest_name: "Jane", guest_email: "jane@example.com")
    request_row.assessment_sessions << assessment_sessions(:draft_squad)

    get guest_access_api_v1_analysis_requests_path(token: request_row.guest_access_token)
    assert_response :success

    linked = response.parsed_body.dig("analysis_request", "assessment_sessions")
    assert_equal [assessment_sessions(:draft_squad).id], linked.map { |s| s["id"] }
    assert_equal "Tuesday squad screening", linked.first["title"]
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

  # --- workflow actions -----------------------------------------------------

  test "staff can accept a request with a price" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(title: "Serve", guest_name: "A", guest_email: "a@example.com")

    post accept_api_v1_analysis_request_path(request),
         params: { price_cents: 4900 }, headers: @headers, as: :json

    assert_response :success
    request.reload
    assert_equal "accepted", request.workflow_status
    assert_equal 4900, request.price_cents
  end

  test "a submitter cannot accept their own request" do
    request = @account.analysis_requests.create!(title: "Mine", guest_name: "Me", guest_email: "me@example.com")

    post accept_api_v1_analysis_request_path(request),
         params: { price_cents: 100 }, headers: @headers, as: :json

    assert_response :forbidden
  end

  test "rejecting requires a reason" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(title: "Serve", guest_name: "A", guest_email: "a@example.com")

    post reject_api_v1_analysis_request_path(request), headers: @headers, as: :json
    assert_response :unprocessable_entity

    post reject_api_v1_analysis_request_path(request),
         params: { reason: "Footage too short" }, headers: @headers, as: :json
    assert_response :success
    assert_equal "rejected", request.reload.workflow_status
  end

  test "invoice and payment transitions move accepted work to in_progress" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(title: "Serve", guest_name: "A", guest_email: "a@example.com")
    request.accept!(price_cents: 4900)

    post mark_invoice_sent_api_v1_analysis_request_path(request),
         params: { external_reference: "INV-1" }, headers: @headers, as: :json
    assert_response :success
    assert_equal "invoice_sent", request.reload.payment_status

    post mark_paid_api_v1_analysis_request_path(request), headers: @headers, as: :json
    assert_response :success
    request.reload
    assert_equal "paid", request.payment_status
    assert_equal "in_progress", request.workflow_status
  end

  test "internal notes are visible to staff and hidden from the submitter" do
    # A distinct member account owns the request, so "submitter" is not the
    # staff user who wrote the note.
    member_user = User.create!(
      email_address: "member-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      email_verified_at: Time.current
    )
    member_account = member_user.create_account!(first_name: "Mia", last_name: "Member")
    request = member_account.analysis_requests.create!(
      title: "My review", description: "Please review"
    )

    @user.add_role(:admin)
    post internal_notes_api_v1_analysis_request_path(request),
         params: { body: "VIP submitter" }, headers: @headers, as: :json
    assert_response :created

    get api_v1_analysis_request_path(request), headers: @headers
    notes = response.parsed_body["analysis_request"]["internal_notes"]
    assert_equal [ "VIP submitter" ], notes.map { |note| note["body"] }

    # The owner sees the request, but never the internal notes.
    _member_session, member_headers = sign_in_with_api_token(member_user)
    get api_v1_analysis_request_path(request), headers: member_headers
    assert_response :success
    assert_not response.parsed_body["analysis_request"].key?("internal_notes")
  end

  test "staff can email the invoice as a PDF" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(
      title: "Serve", guest_name: "A", guest_email: "a@example.com", price_cents: 4900
    )

    assert_enqueued_with(job: AnalysisRequestInvoiceEmailJob) do
      post email_invoice_api_v1_analysis_request_path(request), headers: @headers
    end

    assert_response :accepted
    invoice = request.reload.analysis_request_invoices.sole
    assert_equal 4900, invoice.amount_cents
    assert_equal "pending", invoice.status
  end

  test "a request without a price cannot be invoiced" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(
      title: "Serve", guest_name: "A", guest_email: "a@example.com", price_cents: 0
    )

    assert_no_enqueued_jobs only: AnalysisRequestInvoiceEmailJob do
      post email_invoice_api_v1_analysis_request_path(request), headers: @headers
    end

    assert_response :unprocessable_entity
  end

  test "submitters cannot email invoices" do
    request = @account.analysis_requests.create!(
      title: "Mine", guest_name: "Me", guest_email: "me@example.com", price_cents: 4900
    )

    post email_invoice_api_v1_analysis_request_path(request), headers: @headers

    assert_response :forbidden
  end

  # --- linked analysis -------------------------------------------------------

  test "staff start the analysis and the request exposes progress" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(
      title: "Serve", guest_name: "A", guest_email: "a@example.com", price_cents: 4900
    )
    request.accept!(price_cents: 4900)

    post start_analysis_api_v1_analysis_request_path(request), headers: @headers

    assert_response :created
    payload = response.parsed_body["analysis_request"]["analysis"]
    assert payload["id"].present?
    assert_equal "draft", payload["status"]
    assert_equal 25, payload["percent"]
    assert_not payload["available"]
    assert_nil payload["summary"]
    assert_equal "in_progress", request.reload.workflow_status
  end

  test "starting twice returns the same analysis instead of creating another" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(
      title: "Serve", guest_name: "A", guest_email: "a@example.com", price_cents: 4900
    )
    request.accept!(price_cents: 4900)

    post start_analysis_api_v1_analysis_request_path(request), headers: @headers
    first_id = response.parsed_body["analysis_request"]["analysis"]["id"]

    assert_no_difference -> { Analysis.count } do
      post start_analysis_api_v1_analysis_request_path(request), headers: @headers
    end

    assert_response :ok
    assert_equal first_id, response.parsed_body["analysis_request"]["analysis"]["id"]
  end

  test "a submitter cannot start the analysis" do
    request = @account.analysis_requests.create!(
      title: "Mine", guest_name: "Me", guest_email: "me@example.com", price_cents: 4900
    )
    request.accept!(price_cents: 4900)

    post start_analysis_api_v1_analysis_request_path(request), headers: @headers

    assert_response :forbidden
    assert_nil request.reload.analysis_id
  end

  test "an unapproved request cannot be started" do
    @user.add_role(:admin)
    request = AnalysisRequest.create!(
      title: "Serve", guest_name: "A", guest_email: "a@example.com", price_cents: 4900
    )

    post start_analysis_api_v1_analysis_request_path(request), headers: @headers

    assert_response :unprocessable_entity
    assert_match(/Approve the request/, response.parsed_body["errors"].first)
  end

  test "completing the request publishes and shares the analysis with the guest" do
    @user.add_role(:admin)
    request = analysis_requests(:guest_one)
    request.accept!(price_cents: 4900)
    video = request.analysis_request_videos.create!(
      source_type: "external", external_url: "https://www.youtube.com/watch?v=abc123"
    )
    post start_analysis_api_v1_analysis_request_path(request), headers: @headers
    assert_response :created

    request.reload.analysis.update!(summary: "Toss height and contact point improved.")
    post complete_api_v1_analysis_request_path(request), headers: @headers

    assert_response :success
    assert_equal "published", request.analysis.reload.status
    shared = response.parsed_body["analysis_request"]["analysis"]
    assert shared["available"]
    assert_equal 100, shared["percent"]
    assert_equal "Toss height and contact point improved.", shared["summary"]
    assert_equal video.id, shared["videos"].first["request_video_id"]

    get guest_access_api_v1_analysis_requests_path(token: request.guest_access_token)

    assert_response :success
    guest_analysis = response.parsed_body["analysis_request"]["analysis"]
    assert guest_analysis["available"]
    assert_equal "Toss height and contact point improved.", guest_analysis["summary"]
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