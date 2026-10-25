require "test_helper"

class LocationSupportingModelsTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Support Beach",
      verification_status: "verified",
      verified_at: Time.current,
      source: "test"
    )
  end

  test "court normalizes names, enforces unique names per location, and publishes a summary" do
    court = @location.courts.create!(
      name: "  Centre Court  ",
      latitude: -33.9,
      longitude: 151.2,
      access_instructions: "Enter by the pavilion"
    )

    assert_equal "Centre Court", court.name
    assert_equal "centre court", court.normalized_name
    assert_equal({
      id: court.id,
      location_id: @location.id,
      name: "Centre Court",
      latitude: -33.9,
      longitude: 151.2,
      access_instructions: "Enter by the pavilion",
      status: "active"
    }, court.summary)

    duplicate = @location.courts.build(name: "centre-court")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:normalized_name], "has already been taken"
  end

  test "court requires paired, valid coordinates and exposes active ordering" do
    invalid = @location.courts.build(name: "Bad Court", latitude: 91)
    assert_not invalid.valid?
    assert_includes invalid.errors[:latitude], "must be in -90..90"
    assert_includes invalid.errors[:base], "Latitude and longitude must both be present or both be blank"

    second = @location.courts.create!(name: "Zulu")
    first = @location.courts.create!(name: "Alpha")
    @location.courts.create!(name: "Archived", status: "archived")
    assert_equal [ first.id, second.id ], @location.courts.active.ordered.pluck(:id)
  end

  test "aliases normalize and remain unique within one location" do
    alias_record = @location.aliases.create!(name: "  Support Bch. ")
    assert_equal "Support Bch.", alias_record.name
    assert_equal "support bch", alias_record.normalized_name

    duplicate = @location.aliases.build(name: "support-bch")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:normalized_name], "has already been taken"

    other = Location.create!(name: "Other Beach")
    assert other.aliases.create(name: "Support Bch.").valid?
  end

  test "organisation locations require selectable locations and are unique" do
    organisation = organisations(:fivb)
    link = organisation.organisation_locations.create!(location: @location)
    assert_predicate link, :persisted?

    duplicate = organisation.organisation_locations.build(location: @location)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:location_id], "has already been taken"

    pending = Location.create!(name: "Pending Support Beach", proposed_by_account: accounts(:one))
    unavailable = organisation.organisation_locations.build(location: pending)
    assert_not unavailable.valid?
    assert_includes unavailable.errors[:location], "must be active and verified"
  end
end
