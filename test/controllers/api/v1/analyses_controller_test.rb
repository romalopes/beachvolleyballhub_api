require "test_helper"

# Analyses created from an analysis request expose the link back (IDENTITY-265):
# the editor needs the request reference and each video's request-video origin.
class Api::V1::AnalysesControllerTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  setup do
    @session, @headers = sign_in_with_api_token(users(:two)) # admin
    @analysis_request = analysis_requests(:guest_one)
    @analysis_request.accept!(price_cents: 4900)
    @source_video = @analysis_request.analysis_request_videos.create!(
      source_type: "external", external_url: "https://www.youtube.com/watch?v=abc123"
    )
    @analysis = AnalysisRequests::AnalysisStarter.new(
      request: @analysis_request, actor: users(:two)
    ).call
  end

  test "show includes the originating request and video provenance" do
    get api_v1_analysis_path(@analysis), headers: @headers

    assert_response :success
    body = response.parsed_body["analysis"]
    assert_equal @analysis_request.reference, body["analysis_request"]["reference"]
    assert_equal @source_video.id, body["videos"].first["analysis_request_video_id"]
  end
end
