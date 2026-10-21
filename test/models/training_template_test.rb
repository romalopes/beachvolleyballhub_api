require "test_helper"

class TrainingTemplateTest < ActiveSupport::TestCase
  test "accepts a valid template" do
    assert training_templates(:monday_skills).valid?
  end

  test "requires a name" do
    template = build_template(name: "  ")

    assert_not template.valid?
    assert_includes template.errors.attribute_names, :name
  end

  test "accepts only known statuses" do
    TrainingTemplate::STATUSES.each do |status|
      assert build_template(status: status).valid?, "expected #{status} to be valid"
    end

    template = build_template(status: "draft")
    assert_not template.valid?
    assert_includes template.errors.attribute_names, :status
  end

  test "accepts only known visibilities" do
    TrainingTemplate::VISIBILITIES.each do |visibility|
      assert build_template(visibility: visibility).valid?,
             "expected #{visibility} to be valid"
    end

    template = build_template(visibility: "public")
    assert_not template.valid?
    assert_includes template.errors.attribute_names, :visibility
  end

  test "requires a positive duration and a positive capacity when present" do
    assert_not build_template(duration_minutes: 0).valid?
    assert_not build_template(capacity: 0).valid?
    assert build_template(capacity: nil).valid?
  end

  test "the group must belong to the template's organisation" do
    template = build_template(organisation: organisations(:sydney_club),
                              group: groups(:northern_club_squad))

    assert_not template.valid?
    assert_includes template.errors.attribute_names, :group
  end

  test "allows a group without an organisation" do
    template = build_template(organisation: organisations(:sydney_club),
                              group: groups(:u19_squad))

    assert template.valid?
  end

  test "defaults_for_series snapshots every reusable field" do
    template = training_templates(:monday_skills)

    defaults = template.defaults_for_series

    assert_equal template.name, defaults[:title]
    assert_equal template.description, defaults[:description]
    assert_equal template.organisation_id, defaults[:organisation_id]
    assert_equal template.group_id, defaults[:group_id]
    assert_equal template.coach_profile_id, defaults[:coach_profile_id]
    assert_equal template.location, defaults[:location]
    assert_equal template.location_detail, defaults[:location_detail]
    assert_equal template.level, defaults[:level]
    assert_equal template.capacity, defaults[:capacity]
    assert_equal template.duration_minutes, defaults[:duration_minutes]
    assert_equal template.visibility, defaults[:visibility]
  end

  test "location_summary joins location and detail" do
    template = training_templates(:monday_skills)

    assert_equal "Coogee Beach · Court 1", template.location_summary

    template.location = nil
    assert_equal "Court 1", template.location_summary

    template.location_detail = nil
    assert_nil template.location_summary
  end

  test "status predicates" do
    assert training_templates(:monday_skills).active?
    refute training_templates(:monday_skills).archived?
    assert training_templates(:archived_template).archived?
  end

  test "referenced templates cannot be deleted" do
    assert_equal :restrict_with_error,
                 TrainingTemplate.reflect_on_association(:training_series).options[:dependent]
    assert_equal :restrict_with_error,
                 TrainingTemplate.reflect_on_association(:training_sessions).options[:dependent]
  end

  test "created_by is audit only" do
    reflection = TrainingTemplate.reflect_on_association(:created_by)

    assert_nil reflection.options[:dependent]
    assert reflection.options[:optional]
  end

  private

  def build_template(overrides = {})
    TrainingTemplate.new({
      name: "Sunset Skills",
      description: "Ball control.",
      organisation: organisations(:sydney_club),
      group: groups(:sydney_club_squad),
      coach_profile: coach_profiles(:maria_coach),
      location: "Coogee Beach",
      location_detail: "Court 1",
      level: "intermediate",
      capacity: 12,
      duration_minutes: 90,
      visibility: "shared",
      status: "active",
      created_by: users(:three)
    }.merge(overrides))
  end
end
