require "test_helper"

class Api::V1::TrainingTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)
    @coach = users(:three)
    @curator = users(:four)
    @player = users(:one)
    @template = training_templates(:monday_skills)
  end

  def json
    JSON.parse(response.body)
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def patch_json(path, payload)
    patch path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def valid_payload(overrides = {})
    {
      name: "Sunrise Skills",
      description: "Early ball control.",
      organisation_id: organisations(:sydney_club).id,
      group_id: groups(:sydney_club_squad).id,
      coach_profile_id: coach_profiles(:maria_coach).id,
      location: "Coogee Beach",
      location_detail: "Court 2",
      level: "intermediate",
      capacity: 10,
      duration_minutes: 75,
      visibility: "shared",
      status: "active"
    }.merge(overrides)
  end

  test "a coach can list active templates" do
    sign_in_as(@coach)
    get api_v1_training_templates_path

    assert_response :success
    names = json["data"].map { |template| template["name"] }
    assert_includes names, "Monday Skills"
    refute_includes names, "Retired Fitness Block"
    assert_equal 2, json["meta"]["total"]
  end

  test "include_archived includes archived templates" do
    sign_in_as(@coach)
    get api_v1_training_templates_path, params: { include_archived: "1" }

    assert_response :success
    names = json["data"].map { |template| template["name"] }
    assert_includes names, "Retired Fitness Block"
  end

  test "filters templates by organisation and search" do
    sign_in_as(@coach)
    get api_v1_training_templates_path,
        params: { organisation_id: organisations(:sydney_club).id, q: "Monday" }

    assert_response :success
    assert_equal [ @template.id ], json["data"].map { |template| template["id"] }
  end

  test "rejects an unknown status filter" do
    sign_in_as(@coach)
    get api_v1_training_templates_path, params: { status: "draft" }

    assert_response :unprocessable_entity
    assert_includes json["errors"], "status is not included in the list"
  end

  test "show includes the location summary and associations" do
    sign_in_as(@coach)
    get api_v1_training_template_path(@template)

    assert_response :success
    payload = json["training_template"]
    assert_equal "Coogee Beach · Court 1", payload["location_summary"]
    assert_equal organisations(:sydney_club).id, payload["organisation"]["id"]
    assert_equal coach_profiles(:maria_coach).id, payload["coach_profile"]["id"]
  end

  test "show returns 404 for an unknown template" do
    sign_in_as(@coach)
    get api_v1_training_template_path(999_999)

    assert_response :not_found
  end

  test "a coach can create a template and the creator is audited" do
    sign_in_as(@coach)

    assert_difference -> { TrainingTemplate.count }, 1 do
      post_json api_v1_training_templates_path, training_template: valid_payload
    end

    assert_response :created
    template = TrainingTemplate.order(:id).last
    assert_equal @coach, template.created_by
    assert_equal "Court 2", template.location_detail
    assert_equal 75, template.duration_minutes
  end

  test "a curator can create a template" do
    sign_in_as(@curator)

    assert_difference -> { TrainingTemplate.count }, 1 do
      post_json api_v1_training_templates_path, training_template: valid_payload(name: "Curator block")
    end

    assert_response :created
  end

  test "create rejects invalid attributes" do
    sign_in_as(@coach)

    assert_no_difference -> { TrainingTemplate.count } do
      post_json api_v1_training_templates_path, training_template: valid_payload(name: "")
    end

    assert_response :unprocessable_entity
    assert_includes json["errors"], "Name can't be blank"
  end

  test "a player cannot list or create templates" do
    sign_in_as(@player)
    get api_v1_training_templates_path
    assert_response :forbidden

    assert_no_difference -> { TrainingTemplate.count } do
      post_json api_v1_training_templates_path, training_template: valid_payload
    end
    assert_response :forbidden
  end

  test "a guest is unauthorized" do
    get api_v1_training_templates_path
    assert_response :unauthorized
  end

  test "a coach can update a template" do
    sign_in_as(@coach)
    patch_json api_v1_training_template_path(@template),
               training_template: { capacity: 20, location: "Bondi Beach" }

    assert_response :success
    @template.reload
    assert_equal 20, @template.capacity
    assert_equal "Bondi Beach", @template.location
  end

  test "archive hides the template from the default list and restore brings it back" do
    sign_in_as(@coach)

    post_json archive_api_v1_training_template_path(@template), {}
    assert_response :success
    assert_equal "archived", @template.reload.status

    post_json restore_api_v1_training_template_path(@template), {}
    assert_response :success
    assert_equal "active", @template.reload.status
  end

  test "clone creates an active copy and leaves the original untouched" do
    sign_in_as(@coach)
    training_templates(:archived_template)

    assert_difference -> { TrainingTemplate.count }, 1 do
      post_json clone_api_v1_training_template_path(@template), {}
    end

    assert_response :created
    copy = json["training_template"]
    assert_equal "Monday Skills (copy)", copy["name"]
    assert_equal "active", copy["status"]
    assert_equal "Monday Skills", @template.reload.name
  end

  test "the feature flag disables the endpoints" do
    with_env("RECURRING_TRAINING_ENABLED" => "false") do
      sign_in_as(@coach)
      get api_v1_training_templates_path

      assert_response :not_found
      assert_equal "Recurring training is not available", json["error"]
    end
  end

  private

  def with_env(values)
    old = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    old.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
