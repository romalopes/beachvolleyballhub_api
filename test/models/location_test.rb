require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "generates unique slugs from location names" do
    first = Location.create!(name: "Coogée Beach")
    second = Location.create!(name: "Coogee Beach")

    assert_equal "coogee-beach", first.slug
    assert_equal "coogee-beach-2", second.slug
  end

  test "normalizes names and requires coordinate pairs" do
    location = Location.new(name: "  Coogée Beach  ", latitude: -33.92)

    assert_not location.valid?
    assert_equal "coogee beach", location.normalized_name
    assert_includes location.errors.full_messages,
                    "Latitude and longitude must both be present or both be blank"
  end

  test "search matches aliases" do
    location = verified_location!(name: "Coogee Beach")
    location.aliases.create!(name: "Coogee Bch")

    assert_equal [ location ], Location.search("bch").to_a
  end

  test "verified locations require provenance" do
    location = Location.new(name: "Test Beach", verification_status: "verified")

    assert_not location.valid?
    assert_includes location.errors[:verification_status],
                    "requires verification provenance and time"
  end

  test "only the proposer can use an active pending proposal" do
    proposer = accounts(:one)
    proposal = Location.create!(name: "Pending Beach", proposed_by_account: proposer)

    assert proposal.usable_by?(proposer)
    assert_not proposal.usable_by?(accounts(:two))
    proposal.update!(status: "archived")
    assert_not proposal.usable_by?(proposer)
  end

  test "builds a stable normalized geocoding query and fingerprint" do
    location = Location.new(
      name: " Coogee Beach ", locality: " Sydney ", administrative_area: " NSW ", country_code: "au"
    )

    assert location.geocodable?
    assert_equal "Coogee Beach, Sydney, NSW, AU", location.geocoding_query
    assert_equal location.geocoding_fingerprint, location.geocoding_fingerprint
  end

  private

  def verified_location!(name:)
    Location.create!(
      name: name,
      verification_status: "verified",
      verified_at: Time.current,
      source: "test"
    )
  end
end
