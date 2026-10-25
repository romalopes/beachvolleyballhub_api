require "test_helper"

class LocationDefaultResolverTest < ActiveSupport::TestCase
  setup do
    @organisation = organisations(:fivb)
    @organisation_location = verified_location!("Organisation Default")
    @group_location = verified_location!("Group Default")
    @organisation.organisation_locations.create!(location: @organisation_location)
    @organisation.organisation_locations.create!(location: @group_location)
    @organisation.update!(default_location: @organisation_location)
    @group = Group.create!(
      name: "Default resolver group #{SecureRandom.hex(4)}",
      organisation: @organisation,
      visibility: "shared",
      status: "active"
    )
  end

  test "prefers a group override over its organisation default" do
    @group.update!(default_location: @group_location)

    assert_equal @group_location,
                 LocationDefaultResolver.for_event(
                   group_id: @group.id,
                   organisation_id: @organisation.id
                 )
  end

  test "inherits the group organisation default when there is no override" do
    assert_equal @organisation_location,
                 LocationDefaultResolver.for_event(group_id: @group.id)
  end

  test "falls back to the explicit organisation and returns nil for unknown context" do
    assert_equal @organisation_location,
                 LocationDefaultResolver.for_event(organisation_id: @organisation.id)
    assert_nil LocationDefaultResolver.for_event(group_id: -1, organisation_id: -1)
    assert_nil LocationDefaultResolver.for_event
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
