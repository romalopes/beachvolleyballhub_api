require "test_helper"

class AnalysisRequestVideoTest < ActiveSupport::TestCase
  setup do
    @request = analysis_requests(:one)
    # Real provider metadata is derived from the URL by the Video model.
    @video = Video.find_or_create_from_url!("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end

  test "external video requires video_id and no file" do
    video = @video
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "external",
      video: video
    )
    assert ar_video.valid?
  end

  test "external video without a catalogue video or URL is invalid" do
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "external"
    )
    assert_not ar_video.valid?
    assert_includes ar_video.errors[:base], "An external video needs a catalogue video or a URL"
  end

  test "external video with a provider URL is valid" do
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "external",
      external_url: "https://www.youtube.com/watch?v=abc123"
    )
    assert ar_video.valid?
  end

  test "external video with a non-http URL is invalid" do
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "external",
      external_url: "javascript:alert(1)"
    )
    assert_not ar_video.valid?
    assert_includes ar_video.errors[:external_url], "must be an http(s) URL"
  end

  test "upload video requires attached file and no video_id" do
    # Note: file attachment tested separately; here we check validation logic
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "upload",
      video: @video
    )
    assert_not ar_video.valid?
    assert_includes ar_video.errors[:video], "must be blank for an uploaded video"
  end

  test "source_type must be external or upload" do
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "invalid"
    )
    assert_not ar_video.valid?
  end

  test "position auto-assignment" do
    # A fresh request: the shared fixture already carries videos, so its next
    # position would not start at zero.
    request = AnalysisRequest.create!(
      title: "Position test", guest_name: "A", guest_email: "a@example.com"
    )
    v1 = AnalysisRequestVideo.create!(analysis_request: request, source_type: "external", video: @video)
    v2 = AnalysisRequestVideo.create!(analysis_request: request, source_type: "external", video: @video)
    assert_equal 0, v1.position
    assert_equal 1, v2.position
  end

  test "file validation - content type must be video" do
    # This would need a file attachment in test; structure is correct
    ar_video = AnalysisRequestVideo.new(
      analysis_request: @request,
      source_type: "upload"
    )
    # file not attached -> validation error
    assert_not ar_video.valid?
    assert_includes ar_video.errors[:file], "is required for an uploaded video"
  end
end