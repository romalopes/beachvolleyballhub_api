require "test_helper"

class Api::V1::TrainingSeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)
    @coach = users(:three)
    @curator = users(:four)
    @player = users(:one)
    @template = training_templates(:monday_skills)
    @series = training_series(:monday_series)
  end

  def json
    JSON.parse(response.body)
  end

  def post_json(path, payload)
    post path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
  end

  def payload(overrides = {})
    {
      training_template_id: @template.id,
      starts_on: "2026-11-02",
      ends_on: "2026-11-29",
      weekdays: %w[mon wed],
      local_start_time: "07:00",
      duration_minutes: 90,
      time_zone: "Australia/Sydney",
      frequency: "weekly",
      interval: 1
    }.merge(overrides)
  end

  test "preview returns expanded dates without writing" do
    sign_in_as(@coach)

    assert_no_difference -> { TrainingSession.count } do
      post_json "/api/v1/training_series/preview", training_series: payload
    end

    assert_response :success
    assert json["valid"]
    assert_equal 8, json["total"]
    assert_equal "2026-11-02T07:00", json["occurrences"].first["recurrence_key"]
  end

  test "preview surfaces invalid recurrence input" do
    sign_in_as(@coach)
    post_json "/api/v1/training_series/preview", training_series: payload(weekdays: [])

    assert_response :success
    refute json["valid"]
    assert_includes json["errors"], "Weekdays must include at least one weekday"
    assert_empty json["occurrences"]
  end

  test "preview rejects a missing template" do
    sign_in_as(@coach)
    post_json "/api/v1/training_series/preview", training_series: payload(training_template_id: nil)

    assert_response :unprocessable_entity
    assert_includes json["errors"], "Training template is required"
  end

  test "create persists the series and its occurrences" do
    sign_in_as(@coach)

    assert_difference -> { TrainingSeries.count }, 1 do
      assert_difference -> { TrainingSession.count }, 8 do
        post_json "/api/v1/training_series", training_series: payload
      end
    end

    assert_response :created
    assert_equal 8, json["generation"]["created_count"]
    series = TrainingSeries.order(:id).last
    assert_equal @template, series.training_template
    assert_equal 8, series.training_sessions.count
    assert_equal Date.new(2026, 11, 29), series.generated_through
  end

  test "create snapshots overrides for occurrences" do
    sign_in_as(@coach)
    post_json "/api/v1/training_series",
              training_series: payload(overrides: { title: "Sunrise Skills", capacity: 16 })

    assert_response :created
    series = TrainingSeries.order(:id).last
    session = series.training_sessions.first
    assert_equal "Sunrise Skills", session.title
    assert_equal 16, session.capacity
    assert_equal "Sunrise Skills", json["training_series"]["defaults"]["title"]
  end

  test "create refuses an archived template" do
    sign_in_as(@coach)

    assert_no_difference -> { TrainingSeries.count } do
      post_json "/api/v1/training_series",
                training_series: payload(training_template_id: training_templates(:archived_template).id)
    end

    assert_response :unprocessable_entity
    assert_includes json["errors"], "Archived templates cannot be scheduled"
  end

  test "create rejects an invalid recurrence without writing" do
    sign_in_as(@coach)

    assert_no_difference -> { TrainingSeries.count } do
      assert_no_difference -> { TrainingSession.count } do
        post_json "/api/v1/training_series", training_series: payload(starts_on: "2026-11-29",
                                                                     ends_on: "2026-11-02")
      end
    end

    assert_response :unprocessable_entity
    assert_includes json["errors"], "Ends on must be on or after the start date"
  end

  test "index lists series with filters" do
    sign_in_as(@coach)
    get "/api/v1/training_series"

    assert_response :success
    assert_equal 3, json["meta"]["total"]
    assert_equal 3, json["data"].size

    get "/api/v1/training_series", params: { status: "stopped" }
    assert_response :success
    assert_equal [ training_series(:stopped_series).id ], json["data"].map { |s| s["id"] }

    get "/api/v1/training_series", params: { status: "paused" }
    assert_response :unprocessable_entity
    assert_includes json["errors"], "status is not included in the list"
  end

  test "show includes defaults and occurrence metrics" do
    sign_in_as(@coach)
    get "/api/v1/training_series/#{@series.id}"

    assert_response :success
    series = json["training_series"]
    assert_equal "Monday Skills", series["defaults"]["title"]
    assert_equal "07:00", series["local_start_time"]
    assert_equal Date.new(2026, 11, 2).iso8601, series["next_generation_start"]
    assert_equal 0, series["occurrence_count"]
    refute series["completed"]
    assert_equal 2, series["weekdays"].size
  end

  test "show returns 404 for an unknown series" do
    sign_in_as(@coach)
    get "/api/v1/training_series/999999"

    assert_response :not_found
  end

  test "sessions lists occurrences in schedule order with filters" do
    TrainingSeriesGenerator.new(@series).call
    sign_in_as(@coach)

    get "/api/v1/training_series/#{@series.id}/sessions"
    assert_response :success
    assert_equal 8, json["data"].size
    assert_equal "2026-11-02T07:00", json["data"].first["recurrence_key"]
    assert json["data"].first["cancellable"]
    refute json["data"].first["overridden"]

    get "/api/v1/training_series/#{@series.id}/sessions", params: { status: "cancelled" }
    assert_response :success
    assert_equal 0, json["data"].size

    get "/api/v1/training_series/#{@series.id}/sessions",
        params: { from: "2026-11-10T00:00:00Z", to: "2026-11-20T00:00:00Z" }
    assert_response :success
    assert_equal 3, json["data"].size

    get "/api/v1/training_series/#{@series.id}/sessions", params: { status: "banana" }
    assert_response :unprocessable_entity
    assert_includes json["errors"], "status is not included in the list"
  end

  test "sessions returns 404 for an unknown series" do
    sign_in_as(@coach)
    get "/api/v1/training_series/999999/sessions"

    assert_response :not_found
  end

  test "a player cannot use the series endpoints" do
    sign_in_as(@player)
    get "/api/v1/training_series"
    assert_response :forbidden

    post_json "/api/v1/training_series/preview", training_series: payload
    assert_response :forbidden
  end

  test "a guest is unauthorized" do
    get "/api/v1/training_series"
    assert_response :unauthorized
  end

  test "the feature flag disables the endpoints" do
    with_env("RECURRING_TRAINING_ENABLED" => "false") do
      sign_in_as(@coach)
      get "/api/v1/training_series"

      assert_response :not_found
      assert_equal "Recurring training is not available", json["error"]
    end
  end

  test "bulk_cancel cancels the selected occurrences" do
    TrainingSeriesGenerator.new(@series).call
    ids = @series.training_sessions.order(:starts_at).limit(2).pluck(:id)
    sign_in_as(@coach)

    post_json "/api/v1/training_series/#{@series.id}/bulk_cancel",
              { session_ids: ids, reason: "Storm" }

    assert_response :success
    assert_equal ids.sort, json["affected_ids"].sort
    assert_empty json["skipped"]
    assert_equal 2, @series.training_sessions.where(status: "cancelled").count
    assert_equal "Storm", TrainingSession.find(ids.first).cancellation_reason
  end

  test "bulk_cancel requires a reason" do
    TrainingSeriesGenerator.new(@series).call
    id = @series.training_sessions.first.id
    sign_in_as(@coach)

    post_json "/api/v1/training_series/#{@series.id}/bulk_cancel", { session_ids: [ id ] }

    assert_response :unprocessable_entity
    assert_includes json["errors"], "A cancellation reason is required"
  end

  test "bulk_delete removes an unused draft" do
    TrainingSeriesGenerator.new(@series).call
    draft = @series.training_sessions.first
    draft.update!(status: "draft")
    sign_in_as(@coach)

    assert_difference -> { TrainingSession.count }, -1 do
      post_json "/api/v1/training_series/#{@series.id}/bulk_delete",
                { session_ids: [ draft.id ] }
    end

    assert_response :success
    assert_equal [ draft.id ], json["deleted_ids"]
  end

  test "stop ends recurrence without cancelling occurrences" do
    TrainingSeriesGenerator.new(@series).call
    sign_in_as(@coach)

    post_json "/api/v1/training_series/#{@series.id}/stop", { reason: "Season finished" }

    assert_response :success
    assert json["changed"]
    assert_equal "stopped", @series.reload.status
    assert_equal "Season finished", @series.stopped_reason
    assert_equal 8, @series.training_sessions.where(status: "scheduled").count
  end

  test "cancel_future cancels from the boundary onward" do
    TrainingSeriesGenerator.new(@series).call
    sign_in_as(@coach)

    post_json "/api/v1/training_series/#{@series.id}/cancel_future",
              { from: "2026-11-16", reason: "Venue unavailable" }

    assert_response :success
    assert_equal 4, json["affected_ids"].size
    assert_equal 4, @series.training_sessions.where(status: "cancelled").count
  end

  test "update_future changes future occurrences and preserves earlier ones" do
    TrainingSeriesGenerator.new(@series).call
    sign_in_as(@coach)

    post_json "/api/v1/training_series/#{@series.id}/update_future",
              { effective_from: "2026-11-16",
                changes: { title: "Winter Skills", capacity: 20 } }

    assert_response :success
    assert_equal 4, json["updated_ids"].size
    future = @series.training_sessions.find_by(recurrence_key: "2026-11-16T07:00")
    past = @series.training_sessions.find_by(recurrence_key: "2026-11-02T07:00")
    assert_equal "Winter Skills", future.reload.title
    assert_equal 20, future.capacity
    assert_equal "Monday Skills", past.reload.title
  end

  test "split creates a new series and stops the old one" do
    TrainingSeriesGenerator.new(@series).call
    sign_in_as(@coach)

    assert_difference -> { TrainingSeries.count }, 1 do
      post_json "/api/v1/training_series/#{@series.id}/split",
                { effective_from: "2026-11-16",
                  reason: "Winter schedule",
                  recurrence: { weekdays: %w[thu], local_start_time: "18:00",
                                ends_on: "2026-12-31" } }
    end

    assert_response :success
    assert_equal 4, json["destroyed_count"]
    assert_equal "2026-11-15", @series.reload.ends_on.iso8601
    assert_equal "2026-11-16", json["new_series"]["starts_on"]
    assert_equal %w[thu], json["new_series"]["weekdays"]
    assert_equal Date.new(2026, 11, 16), TrainingSeries.order(:id).last.starts_on
  end

  test "split refuses a future occurrence with participants" do
    TrainingSeriesGenerator.new(@series).call
    future = @series.training_sessions.find_by(recurrence_key: "2026-11-16T07:00")
    TrainingSessionParticipant.create!(
      training_session: future, player_profile: player_profiles(:john_player), status: "confirmed"
    )
    sign_in_as(@coach)

    assert_no_difference -> { TrainingSeries.count } do
      post_json "/api/v1/training_series/#{@series.id}/split",
                { effective_from: "2026-11-16", reason: "Winter schedule",
                  recurrence: { weekdays: %w[thu] } }
    end

    assert_response :unprocessable_entity
    blocker = json["blockers"].find { |row| row["id"] == future.id }
    assert_includes blocker["reasons"], "has_participants"
  end

  test "a player cannot run destructive series actions" do
    TrainingSeriesGenerator.new(@series).call
    id = @series.training_sessions.first.id
    sign_in_as(@player)

    post_json "/api/v1/training_series/#{@series.id}/bulk_cancel",
              { session_ids: [ id ], reason: "Storm" }

    assert_response :forbidden
    assert @series.training_sessions.find(id).scheduled?
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
