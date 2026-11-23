require "test_helper"

class Api::V1::AnalysisPackagesControllerTest < ActionDispatch::IntegrationTest
  test "index - returns active packages only" do
    get api_v1_analysis_packages_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 3, json["data"].count
    keys = json["data"].map { |p| p["key"] }
    assert_includes keys, "complimentary"
    assert_includes keys, "single_match"
    assert_includes keys, "season_review"
    assert_not_includes keys, "inactive"
  end

  test "index - packages ordered by position" do
    get api_v1_analysis_packages_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "complimentary", json["data"].first["key"]
    assert_equal "single_match", json["data"].second["key"]
    assert_equal "season_review", json["data"].third["key"]
  end

  test "index - includes all package fields" do
    get api_v1_analysis_packages_path
    assert_response :success

    json = JSON.parse(response.body)
    pkg = json["data"].find { |p| p["key"] == "single_match" }

    assert_equal "Single Match Analysis", pkg["name"]
    assert_equal 4900, pkg["price_cents"]
    assert_equal "$49.00 AUD", pkg["price_aud"]
    assert_equal 1, pkg["max_videos"]
    assert_equal 60, pkg["max_duration_minutes"]
    assert_equal false, pkg["includes_annotated_video"]
    assert_equal true, pkg["includes_written_report"]
    assert_equal false, pkg["includes_consultation"]
    assert_equal 7, pkg["turnaround_days"]
  end

  test "index - works without authentication" do
    get api_v1_analysis_packages_path
    assert_response :success
  end
end