require "test_helper"

# Starting production for an approved request (IDENTITY-265).
class AnalysisRequests::AnalysisStarterTest < ActiveSupport::TestCase
  setup do
    @request = analysis_requests(:one)
    @actor = users(:two)
  end

  test "creates a linked draft analysis and starts the request" do
    @request.accept!(price_cents: 4900)

    analysis = AnalysisRequests::AnalysisStarter.new(request: @request, actor: @actor).call

    assert_equal "draft", analysis.status
    assert_equal @request.title, analysis.title
    assert_equal @actor.id, analysis.created_by_id
    assert_equal analysis.id, @request.reload.analysis_id
    assert_equal "in_progress", @request.workflow_status
    assert @request.work_started_at.present?
  end

  test "copies external videos into catalogue videos" do
    @request.accept!(price_cents: 4900)
    source = @request.analysis_request_videos.create!(
      source_type: "external", external_url: "https://www.youtube.com/watch?v=abc123"
    )

    analysis = AnalysisRequests::AnalysisStarter.new(request: @request, actor: @actor).call

    copied = analysis.analysis_videos.sole
    assert_equal source.id, copied.analysis_request_video_id
    assert_equal "external", copied.source_type
    assert_equal "youtube", copied.video.provider
    assert_equal "abc123", copied.video.provider_video_id
  end

  test "shares the uploaded blob instead of copying bytes" do
    @request.accept!(price_cents: 4900)
    source = @request.analysis_request_videos.new(source_type: "upload")
    source.file.attach(io: StringIO.new("video-bytes"), filename: "clip.mp4", content_type: "video/mp4")
    source.save!

    analysis = AnalysisRequests::AnalysisStarter.new(request: @request, actor: @actor).call

    copied = analysis.analysis_videos.sole
    assert_equal source.id, copied.analysis_request_video_id
    assert copied.file.attached?
    assert_equal source.file.blob.id, copied.file.blob.id
  end

  test "refuses a request the team has not approved" do
    error = assert_raises(AnalysisRequests::AnalysisStarter::NotApproved) do
      AnalysisRequests::AnalysisStarter.new(request: @request, actor: @actor).call
    end

    assert_match(/Approve the request/, error.message)
    assert_nil @request.reload.analysis_id
  end

  test "refuses to start twice" do
    @request.accept!(price_cents: 4900)
    AnalysisRequests::AnalysisStarter.new(request: @request, actor: @actor).call

    assert_raises(AnalysisRequests::AnalysisStarter::AlreadyStarted) do
      AnalysisRequests::AnalysisStarter.new(request: @request.reload, actor: @actor).call
    end
  end

  test "notifies the submitter that work started" do
    @request.accept!(price_cents: 4900)

    assert_difference -> { Notification.where(event_type: "analysis_request.work_started").count }, 1 do
      AnalysisRequests::AnalysisStarter.new(request: @request, actor: @actor).call
    end
  end
end
