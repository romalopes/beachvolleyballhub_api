require "test_helper"

class DrillTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      title: "Serve Drill",
      setup_instructions: "Serve and recover.",
      training_stage: "beginning",
      difficulty_level: "intermediate",
      min_players: 2,
      max_players: 8,
      ideal_num_players: 4
    }.merge(overrides)
  end

  test "accepts valid training attributes" do
    assert Drill.new(valid_attributes).valid?
  end

  test "defaults are blank on new records" do
    drill = Drill.new(title: "Defaults Drill")
    assert_nil drill.training_stage
    assert_nil drill.difficulty_level
    assert_nil drill.min_players
    assert_nil drill.max_players
    assert_nil drill.ideal_num_players
    assert drill.valid?
  end

  test "rejects unknown training stage" do
    drill = Drill.new(valid_attributes(training_stage: "preps"))
    assert_not drill.valid?
    assert_includes drill.errors.attribute_names, :training_stage
  end

  test "rejects unknown difficulty" do
    drill = Drill.new(valid_attributes(difficulty_level: "expert"))
    assert_not drill.valid?
    assert_includes drill.errors.attribute_names, :difficulty_level
  end

  test "rejects min greater than max" do
    drill = Drill.new(valid_attributes(min_players: 8, max_players: 2, ideal_num_players: 4))
    assert_not drill.valid?
    assert_includes drill.errors.attribute_names, :min_players
  end

  test "rejects ideal below min" do
    drill = Drill.new(valid_attributes(min_players: 2, max_players: 8, ideal_num_players: 1))
    assert_not drill.valid?
    assert_includes drill.errors.attribute_names, :ideal_num_players
  end

  test "rejects ideal above max" do
    drill = Drill.new(valid_attributes(min_players: 2, max_players: 4, ideal_num_players: 8))
    assert_not drill.valid?
    assert_includes drill.errors.attribute_names, :ideal_num_players
  end

  test "accepts ideal equal to range boundaries" do
    assert Drill.new(valid_attributes(min_players: 2, max_players: 4, ideal_num_players: 2)).valid?
    assert Drill.new(valid_attributes(min_players: 2, max_players: 4, ideal_num_players: 4)).valid?
  end

  test "accepts null training attributes" do
    drill = Drill.new(valid_attributes(
      training_stage: nil,
      difficulty_level: nil,
      min_players: nil,
      max_players: nil,
      ideal_num_players: nil
    ))
    assert drill.valid?
  end

  test "accepts partial training attributes" do
    assert Drill.new(valid_attributes(ideal_num_players: nil)).valid?
    assert Drill.new(valid_attributes(max_players: nil, ideal_num_players: nil)).valid?
    assert Drill.new(valid_attributes(training_stage: nil)).valid?
  end

  test "labels handle missing attributes" do
    drill = Drill.new(valid_attributes(ideal_num_players: nil))
    assert_nil drill.ideal_label
    assert_nil Drill.new(valid_attributes(min_players: nil, max_players: nil, ideal_num_players: nil)).player_range_label
    assert_nil Drill.new(valid_attributes(training_stage: nil)).training_stage_label
  end

  test "range and ideal labels" do
    drill = Drill.new(valid_attributes(min_players: 2, max_players: 4, ideal_num_players: 3))
    assert_equal "2–4 players", drill.player_range_label
    assert_equal "Ideal: 3", drill.ideal_label
    assert_equal "Beginning", drill.training_stage_label
    single = Drill.new(valid_attributes(min_players: 2, max_players: 2, ideal_num_players: 2))
    assert_equal "2 players", single.player_range_label
    assert_equal "Warm-up", Drill.new(valid_attributes(training_stage: "warmup")).training_stage_label
  end

  test "generates a slug from the title" do
    drill = Drill.create!(valid_attributes(title: "Overhead Set Drill"))
    assert_equal "overhead-set-drill", drill.slug
  end
  test "generates unique slugs for duplicate titles" do
    a = Drill.create!(valid_attributes(title: "Same Name Drill"))
    b = Drill.create!(valid_attributes(title: "Same Name Drill"))
    assert_equal "same-name-drill", a.slug
    assert_equal "same-name-drill-2", b.slug
  end
  test "regenerates slug when the title changes" do
    drill = Drill.create!(valid_attributes(title: "Original Title"))
    drill.update!(title: "New Title")
    assert_equal "new-title", drill.reload.slug
  end
  test "to_param returns the slug" do
    drill = Drill.create!(valid_attributes(title: "Param Test"))
    assert_equal "param-test", drill.to_param
  end

  # ---------- visibility / status / approval ----------

  test "defaults to draft status and shared visibility" do
    drill = Drill.create!(valid_attributes(title: "Default State Drill"))
    assert_equal "draft", drill.status
    assert_equal "shared", drill.visibility
    assert_nil drill.published_at
  end

  test "rejects an unknown visibility" do
    # Rails enums raise ArgumentError on an unknown value rather than recording
    # a validation error, so an invalid visibility can never be persisted.
    assert_raises(ArgumentError) do
      Drill.new(valid_attributes(visibility: "secret"))
    end
  end

  test "rejects an unknown status" do
    assert_raises(ArgumentError) do
      Drill.new(valid_attributes(status: "live"))
    end
  end

  test "published_and_shared? is true only for published shared drills" do
    published_shared = Drill.create!(valid_attributes(
      title: "Published Shared", status: :published, visibility: :shared
    ))
    assert published_shared.published_and_shared?

    draft = Drill.create!(valid_attributes(
      title: "Still Draft", status: :draft, visibility: :shared
    ))
    assert_not draft.published_and_shared?

    private_published = Drill.create!(valid_attributes(
      title: "Private Published", status: :published, visibility: :private
    ))
    assert_not private_published.published_and_shared?
  end

  test "published_and_shared scope excludes non-public drills" do
    visible = Drill.create!(valid_attributes(
      title: "Visible Drill", status: :published, visibility: :shared
    ))
    hidden_draft = Drill.create!(valid_attributes(
      title: "Hidden Draft", status: :draft, visibility: :shared
    ))
    hidden_private = Drill.create!(valid_attributes(
      title: "Hidden Private", status: :published, visibility: :private
    ))
    hidden_unlisted = Drill.create!(valid_attributes(
      title: "Hidden Unlisted", status: :published, visibility: :unlisted
    ))

    ids = Drill.published_and_shared.pluck(:id)
    assert_includes ids, visible.id
    assert_not_includes ids, hidden_draft.id
    assert_not_includes ids, hidden_private.id
    assert_not_includes ids, hidden_unlisted.id
  end

  test "publish! stamps published_at and records the approver" do
    approver = users(:two)
    drill = Drill.create!(valid_attributes(title: "To Publish"))

    drill.publish!(approver: approver)

    assert_equal "published", drill.reload.status
    assert_not_nil drill.published_at
    assert_equal approver.id, drill.approved_by_id
  end

  test "reject! records the approval time and approver" do
    approver = users(:two)
    drill = Drill.create!(valid_attributes(title: "To Reject", status: :submitted))

    drill.reject!(approver: approver)

    assert_equal "rejected", drill.reload.status
    assert_not_nil drill.approved_at
    assert_equal approver.id, drill.approved_by_id
  end

  test "stamps published_at automatically when status becomes published" do
    drill = Drill.create!(valid_attributes(title: "Auto Stamp", status: :draft))
    assert_nil drill.published_at

    drill.update!(status: :published)
    assert_not_nil drill.reload.published_at
  end
end
