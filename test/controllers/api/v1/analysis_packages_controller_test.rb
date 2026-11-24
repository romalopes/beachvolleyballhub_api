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

  # --- admin_index (management listing) --------------------------------------

  test "admin_index - requires authentication" do
    get admin_index_api_v1_analysis_packages_path
    assert_response :unauthorized
  end

  test "admin_index - forbidden for non-admins" do
    _session, headers = sign_in_with_api_token(users(:five)) # plain player
    get admin_index_api_v1_analysis_packages_path, headers: headers
    assert_response :forbidden
  end

  test "admin_index - returns every package including inactive ones" do
    _session, headers = sign_in_with_api_token(users(:two)) # admin
    get admin_index_api_v1_analysis_packages_path, headers: headers
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 4, json["data"].count
    keys = json["data"].map { |p| p["key"] }
    assert_includes keys, "inactive"
    # Ordered by position like the public list.
    assert_equal json["data"].map { |p| p["position"] }, json["data"].map { |p| p["position"] }.sort
  end

  # --- show -------------------------------------------------------------------

  test "show - works without authentication and includes the id" do
    package = analysis_packages(:single_match)
    get api_v1_analysis_package_path(package)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal package.id, json["package"]["id"]
    assert_equal "single_match", json["package"]["key"]
  end

  test "show - unknown id is a 404" do
    get api_v1_analysis_package_path(id: 0)
    assert_response :not_found
  end

  # --- create -----------------------------------------------------------------

  test "create - admin can create a package" do
    _session, headers = sign_in_with_api_token(users(:two))

    assert_difference "AnalysisPackage.count", 1 do
      post api_v1_analysis_packages_path, params: {
        analysis_package: {
          key: "double_match",
          name: "Double Match Analysis",
          description: "Two matches reviewed end to end",
          price_cents: 8900,
          max_videos: 2,
          max_duration_minutes: 90,
          includes_annotated_video: true,
          includes_written_report: true,
          includes_consultation: false,
          turnaround_days: 5,
          position: 4,
          active: true
        }
      }, headers: headers, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "double_match", json["package"]["key"]
    assert_equal 8900, json["package"]["price_cents"]
    assert_equal true, json["package"]["includes_annotated_video"]

    created = AnalysisPackage.find_by!(key: "double_match")
    assert_equal 4, created.position
    assert created.active
  end

  test "create - forbidden for non-admins" do
    _session, headers = sign_in_with_api_token(users(:five))

    assert_no_difference "AnalysisPackage.count" do
      post api_v1_analysis_packages_path, params: {
        analysis_package: { key: "sneaky", name: "Sneaky", description: "Nope" }
      }, headers: headers, as: :json
    end
    assert_response :forbidden
  end

  test "create - blank key is unprocessable" do
    _session, headers = sign_in_with_api_token(users(:two))

    post api_v1_analysis_packages_path, params: {
      analysis_package: { key: "", name: "No key", description: "Missing key" }
    }, headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_not_empty JSON.parse(response.body)["errors"]
  end

  test "create - duplicate key is unprocessable" do
    _session, headers = sign_in_with_api_token(users(:two))

    post api_v1_analysis_packages_path, params: {
      analysis_package: {
        key: "single_match",
        name: "Duplicate",
        description: "Same key as an existing package"
      }
    }, headers: headers, as: :json
    assert_response :unprocessable_entity
  end

  # --- update -----------------------------------------------------------------

  test "update - admin can change price and visibility" do
    _session, headers = sign_in_with_api_token(users(:two))
    package = analysis_packages(:single_match)

    patch api_v1_analysis_package_path(package), params: {
      analysis_package: { price_cents: 5900, active: false }
    }, headers: headers, as: :json

    assert_response :success
    package.reload
    assert_equal 5900, package.price_cents
    assert_not package.active
  end

  test "update - forbidden for non-admins" do
    _session, headers = sign_in_with_api_token(users(:five))

    patch api_v1_analysis_package_path(analysis_packages(:single_match)), params: {
      analysis_package: { price_cents: 1 }
    }, headers: headers, as: :json
    assert_response :forbidden
  end

  test "update - unknown id is a 404" do
    _session, headers = sign_in_with_api_token(users(:two))

    patch api_v1_analysis_package_path(id: 0), params: {
      analysis_package: { price_cents: 1 }
    }, headers: headers, as: :json
    assert_response :not_found
  end

  # --- destroy ----------------------------------------------------------------

  test "destroy - admin can delete a package" do
    _session, headers = sign_in_with_api_token(users(:two))
    package = analysis_packages(:season_review)

    assert_difference "AnalysisPackage.count", -1 do
      delete api_v1_analysis_package_path(package), headers: headers, as: :json
    end

    assert_response :no_content
    assert_nil AnalysisPackage.find_by(key: "season_review")
  end

  test "destroy - forbidden for non-admins" do
    _session, headers = sign_in_with_api_token(users(:five))

    assert_no_difference "AnalysisPackage.count" do
      delete api_v1_analysis_package_path(analysis_packages(:season_review)), headers: headers, as: :json
    end
    assert_response :forbidden
  end
end