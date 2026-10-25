require "test_helper"

class Api::V1::OrganisationLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:two)
    @admin.add_role(:admin) unless @admin.admin?
    # `two` owns the Sydney club, so it can attach and detach its venues.
    @owner = users(:two)
    @organisation = organisations(:sydney_club)
    @verified = Location.create!(
      name: "Coogee Beach",
      verification_status: "verified",
      verified_at: Time.current,
      verified_by_account: @admin.account,
      latitude: -33.9205,
      longitude: 151.2552
    )
  end

  test "an owner lists the venues attached to their organisation" do
    OrganisationLocation.create!(organisation: @organisation, location: @verified)
    sign_in_as(@owner)

    get api_v1_organisation_organisation_locations_path(@organisation)

    assert_response :success
    rows = response.parsed_body.fetch("locations")
    assert_equal [ @verified.id ], rows.map { |row| row.fetch("id") }
    # The attachment carries its own id, which is what a detach addresses.
    assert_equal OrganisationLocation.first.id, rows.first.fetch("association_id")
    assert_equal false, rows.first.fetch("default")
  end

  test "an owner attaches a verified venue" do
    sign_in_as(@owner)

    post api_v1_organisation_organisation_locations_path(@organisation),
         params: { organisation_location: { location_id: @verified.id } }

    assert_response :created
    assert @organisation.reload.organisation_locations.exists?(location: @verified)
  end

  test "an unverified venue cannot be attached" do
    proposed = Location.create!(name: "Pending Beach")
    sign_in_as(@owner)

    post api_v1_organisation_organisation_locations_path(@organisation),
         params: { organisation_location: { location_id: proposed.id } }

    assert_response :unprocessable_entity
  end

  test "an owner detaches a venue by its association id" do
    attachment = OrganisationLocation.create!(
      organisation: @organisation,
      location: @verified
    )
    sign_in_as(@owner)

    delete api_v1_organisation_organisation_location_path(@organisation, attachment)

    assert_response :no_content
    assert_not @organisation.reload.organisation_locations.exists?
  end

  test "the default venue cannot be detached" do
    attachment = OrganisationLocation.create!(
      organisation: @organisation,
      location: @verified
    )
    @organisation.update!(default_location: @verified)
    sign_in_as(@owner)

    delete api_v1_organisation_organisation_location_path(@organisation, attachment)

    assert_response :unprocessable_entity
    assert @organisation.reload.organisation_locations.exists?
  end

  test "a default must be one of the organisation's own venues" do
    other = Location.create!(
      name: "Bondi Beach",
      verification_status: "verified",
      verified_at: Time.current,
      verified_by_account: @admin.account,
      latitude: -33.89,
      longitude: 151.27
    )
    sign_in_as(@owner)

    patch api_v1_organisation_path(@organisation),
          params: { organisation: { default_location_id: other.id } }

    assert_response :unprocessable_entity
  end

  test "an attached venue can be made the organisation's default" do
    OrganisationLocation.create!(organisation: @organisation, location: @verified)
    sign_in_as(@owner)

    patch api_v1_organisation_path(@organisation),
          params: { organisation: { default_location_id: @verified.id } }

    assert_response :success
    assert_equal @verified.id, @organisation.reload.default_location_id
  end

  test "a non-member cannot attach a venue" do
    sign_in_as(users(:one))

    post api_v1_organisation_organisation_locations_path(@organisation),
         params: { organisation_location: { location_id: @verified.id } }

    assert_response :forbidden
  end
end
