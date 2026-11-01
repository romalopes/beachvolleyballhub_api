require "test_helper"

class Api::V1::DrillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)    # coach + admin
    @coach = users(:three)  # coach role only
    @player = users(:one)   # player role only
    @owned = Drill.create!(
      title: "Owned Drill",
      setup_instructions: "Setup",
      training_stage: "beginning",
      difficulty_level: "beginner",
      min_players: 2,
      max_players: 8,
      ideal_num_players: 4,
      created_by: @coach,
      status: :published,
      visibility: :shared,
      published_at: Time.current
    )
  end

  # ---------- index / show (public) ----------

  test "index is public and excludes the raw definition column" do
    # Create a published drill that should appear in the public index
    public_drill = Drill.create!(
      title: "Public Index Drill",
      setup_instructions: "Setup",
      training_stage: "beginning",
      difficulty_level: "beginner",
      min_players: 2,
      max_players: 4,
      ideal_num_players: 2,
      created_by: @coach,
      status: :published,
      visibility: :shared,
      published_at: Time.current
    )

    get "/api/v1/drills"
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
    drill = body.find { |d| d["id"] == public_drill.id }
    assert_not_nil drill
    assert_not drill.key?("definition")
    # `has_definition` stands in for the omitted column.
    assert_equal false, drill["has_definition"]
    assert drill.key?("skills")
  end

  test "index flags drills that carry a visual definition" do
    visual = Drill.create!(title: "Visual Drill", definition: visual_drill_definition, status: :published, visibility: :shared, published_at: Time.current)

    get "/api/v1/drills"
    assert_response :success
    body = JSON.parse(response.body)

    drill = body.find { |d| d["id"] == visual.id }
    assert_not_nil drill
    assert_equal true, drill["has_definition"]
    # The heavy definition blob stays out of the list payload.
    assert_not drill.key?("definition")
  end

  test "show is public and includes skills, video_references and training_sessions" do
    public_drill = Drill.create!(
      title: "Public Show Drill",
      setup_instructions: "Setup",
      training_stage: "beginning",
      difficulty_level: "beginner",
      min_players: 2,
      max_players: 4,
      ideal_num_players: 2,
      created_by: @coach,
      status: :published,
      visibility: :shared,
      published_at: Time.current
    )

    get "/api/v1/drills/public-show-drill"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "public-show-drill", body["slug"]
    assert body.key?("skills")
    assert body.key?("video_references")
    assert body.key?("training_sessions")
  end

  test "show falls back to lookup by id" do
    drill = Drill.create!(
      title: "Lookup Drill",
      setup_instructions: "Setup",
      training_stage: "beginning",
      difficulty_level: "beginner",
      min_players: 2,
      max_players: 4,
      ideal_num_players: 2,
      created_by: @coach,
      status: :published,
      visibility: :shared,
      published_at: Time.current
    )
    get "/api/v1/drills/#{drill.id}"
    assert_response :success
    assert_equal drill.id, JSON.parse(response.body)["id"]
  end

  test "show of an unknown slug renders 404" do
    # set_drill finds nothing and @drill is nil, so the controller returns 404.
    sign_in_as(@coach)
    get "/api/v1/drills/no-such-drill"
    assert_response :not_found
    assert_equal "Drill not found", JSON.parse(response.body)["error"]
  end

  # ---------- drill-specific visibility / status enforcement ----------

  test "index excludes draft drills" do
    draft = Drill.create!(
      title: "Draft Drill",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @coach,
      status: :draft,
      visibility: :shared
    )

    get "/api/v1/drills"
    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body.find { |d| d["id"] == draft.id }, "draft drill must not appear in the public index"
  end

  test "index excludes private and unlisted drills" do
    private_drill = Drill.create!(
      title: "Private Drill",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @coach,
      status: :published,
      visibility: :private,
      published_at: Time.current
    )
    unlisted_drill = Drill.create!(
      title: "Unlisted Drill",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @coach,
      status: :published,
      visibility: :unlisted,
      published_at: Time.current
    )

    get "/api/v1/drills"
    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body.find { |d| d["id"] == private_drill.id }, "private drill must not appear in the public index"
    assert_nil body.find { |d| d["id"] == unlisted_drill.id }, "unlisted drill must not appear in the public index"
  end

  test "guest cannot view a draft drill by slug" do
    draft = Drill.create!(
      title: "Secret Draft",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @coach,
      status: :draft,
      visibility: :shared
    )

    get "/api/v1/drills/#{draft.slug}"
    assert_response :not_found
  end

  test "guest cannot view a private published drill by slug" do
    private_drill = Drill.create!(
      title: "Private Published",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @coach,
      status: :published,
      visibility: :private,
      published_at: Time.current
    )

    get "/api/v1/drills/#{private_drill.slug}"
    assert_response :not_found
  end

  test "owner can view their own draft drill" do
    draft = Drill.create!(
      title: "My Draft",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @coach,
      status: :draft,
      visibility: :shared
    )

    sign_in_as(@coach)
    get "/api/v1/drills/#{draft.slug}"
    assert_response :success
    assert_equal draft.id, JSON.parse(response.body)["id"]
  end

  test "coach creating a drill gets submitted status (not published)" do
    sign_in_as(@coach)
    post "/api/v1/drills", params: { drill: {
      title: "Submitted Drill",
      training_stage: "warmup",
      difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2
    } }

    assert_response :created
    created = Drill.find_by(title: "Submitted Drill")
    assert_equal "submitted", created.status
    assert_nil created.published_at
  end

  test "player cannot change a drill status" do
    sign_in_as(@player)
    patch "/api/v1/drills/#{@owned.slug}", params: { drill: { status: "archived" } }
    assert_response :forbidden
    assert_equal "published", @owned.reload.status
  end

  test "non-owner coach cannot change visibility of another coach's drill" do
    other = Drill.create!(
      title: "Other Coach Drill",
      training_stage: "middle",
      difficulty_level: "intermediate",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @admin,
      status: :published,
      visibility: :shared,
      published_at: Time.current
    )

    sign_in_as(@coach)
    patch "/api/v1/drills/#{other.slug}", params: { drill: { visibility: "private" } }
    assert_response :forbidden
    assert_equal "shared", other.reload.visibility
  end

  # ---------- create ----------

  test "coach can create a drill" do
    sign_in_as(@coach)
    assert_difference("Drill.count") do
      post "/api/v1/drills", params: { drill: {
        title: "New Drill",
        setup_instructions: "Warm up",
        training_stage: "warmup",
        difficulty_level: "beginner",
        min_players: 2,
        max_players: 6,
        ideal_num_players: 4
      } }
    end
    assert_response :created
    assert_equal @coach.id, Drill.find_by(title: "New Drill").created_by_id
  end

  test "player cannot create a drill" do
    sign_in_as(@player)
    post "/api/v1/drills", params: { drill: {
      title: "Blocked", training_stage: "warmup", difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2
    } }
    assert_response :forbidden
  end

  test "guest cannot create a drill" do
    post "/api/v1/drills", params: { drill: {
      title: "Blocked", training_stage: "warmup", difficulty_level: "beginner",
      min_players: 2, max_players: 4, ideal_num_players: 2
    } }
    assert_response :unauthorized
  end

  test "create returns 422 on validation errors" do
    sign_in_as(@coach)
    post "/api/v1/drills", params: { drill: { title: "" } }
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  # ---------- update / destroy (owner or admin) ----------

  test "owner can update their drill" do
    sign_in_as(@coach)
    patch "/api/v1/drills/#{@owned.slug}", params: { drill: { title: "Renamed" } }
    assert_response :success
    assert_equal "Renamed", @owned.reload.title
  end

  test "non-owner coach cannot update another coach's drill" do
    other = Drill.create!(
      title: "Admins Drill",
      training_stage: "middle",
      difficulty_level: "intermediate",
      min_players: 2, max_players: 4, ideal_num_players: 2,
      created_by: @admin
    )
    sign_in_as(@coach)
    patch "/api/v1/drills/#{other.slug}", params: { drill: { title: "Hacked" } }
    assert_response :forbidden
  end

  test "admin can update any drill" do
    sign_in_as(@admin)
    patch "/api/v1/drills/#{@owned.slug}", params: { drill: { title: "Admin edited" } }
    assert_response :success
    assert_equal "Admin edited", @owned.reload.title
  end

  test "update returns 422 on validation errors" do
    sign_in_as(@coach)
    patch "/api/v1/drills/#{@owned.slug}", params: { drill: { min_players: 99, max_players: 1 } }
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "owner can destroy their drill" do
    sign_in_as(@coach)
    assert_difference("Drill.count", -1) do
      delete "/api/v1/drills/#{@owned.slug}"
    end
    assert_response :no_content
  end

  test "guest cannot destroy a drill" do
    delete "/api/v1/drills/#{@owned.slug}"
    assert_response :unauthorized
    assert Drill.exists?(@owned.id)
  end
end
