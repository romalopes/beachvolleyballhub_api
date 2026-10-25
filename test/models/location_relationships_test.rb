require "test_helper"

class LocationRelationshipsTest < ActiveSupport::TestCase
  setup do
    @location = verified_location!("Manly Beach")
    @other_location = verified_location!("Bondi Beach")
    @court = @location.courts.create!(name: "Court 1")
  end

  test "organisation default must be associated" do
    organisation = organisations(:fivb)
    organisation.default_location = @location

    assert_not organisation.valid?

    organisation.organisation_locations.build(location: @location)
    assert organisation.valid?
  end

  test "group inherits organisation default and may override it" do
    organisation = organisations(:fivb)
    organisation.organisation_locations.create!(location: @location)
    organisation.update!(default_location: @location)
    group = Group.create!(
      name: "Location inheritance group",
      organisation: organisation,
      visibility: "shared",
      status: "active"
    )

    assert_equal @location.id, group.metadata[:effective_default_location][:id]

    organisation.organisation_locations.create!(location: @other_location)
    group.update!(default_location: @other_location)
    assert_equal @other_location.id, group.metadata[:effective_default_location][:id]
  end

  test "event court must belong to its location" do
    training = training_sessions(:one)
    training.canonical_location = @other_location
    training.court = @court

    assert_not training.valid?
    assert_includes training.errors[:court], "must belong to the selected location"
  end

  private

  def verified_location!(name)
    Location.create!(
      name: name,
      verification_status: "verified",
      verified_at: Time.current,
      source: "test"
    )
  end
end
