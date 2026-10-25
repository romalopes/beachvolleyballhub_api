require "test_helper"

class Api::V1::LocationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = users(:two)
    @admin.add_role(:admin) unless @admin.admin?
    @player = users(:one)
    @player.add_role(:player) unless @player.player?
    @verified = Location.create!(
      name: "Coogee Beach",
      verification_status: "verified",
      verified_at: Time.current,
      source: "test",
      latitude: -33.9205,
      longitude: 151.2552
    )
  end

  test "ordinary users list only verified active locations" do
    Location.create!(name: "Pending Beach")
    sign_in_as(@player)

    get api_v1_locations_path

    assert_response :success
    assert_equal [ @verified.id ],
                 response.parsed_body.fetch("locations").map { |row| row.fetch("id") }
  end

  test "ordinary users list their own active proposals but not another account's" do
    account_player = users(:five)
    account_player.add_role(:player) unless account_player.player?
    own = Location.create!(name: "My Pending Beach", proposed_by_account: account_player.account)
    Location.create!(name: "Other Pending Beach", proposed_by_account: accounts(:two))
    sign_in_as(account_player)

    get api_v1_locations_path

    assert_response :success
    ids = response.parsed_body.fetch("locations").map { |row| row.fetch("id") }
    assert_includes ids, @verified.id
    assert_includes ids, own.id
    assert_equal 2, ids.length
  end

  test "ordinary users can show only their own proposal" do
    account_player = users(:five)
    account_player.add_role(:player) unless account_player.player?
    own = Location.create!(name: "My Pending Beach", proposed_by_account: account_player.account)
    other = Location.create!(name: "Other Pending Beach", proposed_by_account: accounts(:two))
    sign_in_as(account_player)

    get api_v1_location_path(own)
    assert_response :success

    get api_v1_location_path(other)
    assert_response :not_found
  end

  test "locations can be shown by slug and include the slug in the payload" do
    sign_in_as(@player)

    get api_v1_location_path(@verified.slug)

    assert_response :success
    assert_equal @verified.id, response.parsed_body.dig("location", "id")
    assert_equal "coogee-beach", response.parsed_body.dig("location", "slug")
  end

  test "authenticated users can propose but cannot set coordinates" do
    sign_in_as(@player)

    post api_v1_locations_path, params: {
      location: { name: "New Beach", latitude: -33.1, longitude: 151.1 }
    }

    assert_response :created
    location = Location.find(response.parsed_body.dig("location", "id"))
    assert_equal "proposed", location.verification_status
    assert_nil location.latitude
  end

  test "address proposals are marked pending and enqueue geocoding" do
    sign_in_as(@player)

    with_geocoding_config do
      assert_enqueued_with(job: LocationGeocodingJob) do
        post api_v1_locations_path, params: {
          location: { name: "New Beach", locality: "Sydney", country_code: "AU" }
        }
      end
    end

    location = Location.find(response.parsed_body.dig("location", "id"))
    assert_equal "pending", location.geocoding_status
  end

  test "admin can verify a proposal" do
    proposal = Location.create!(name: "Proposed Beach")
    sign_in_as(@admin)

    post verify_api_v1_location_path(proposal)

    assert_response :success
    assert_equal "verified", proposal.reload.verification_status
    assert_equal @admin.account.id, proposal.verified_by_account_id
  end

  test "changing an automatically geocoded address clears stale coordinates when geocoding is disabled" do
    location = Location.create!(
      name: "Old Beach",
      locality: "Sydney",
      country_code: "AU",
      latitude: -33.9,
      longitude: 151.2,
      geocoding_status: "resolved",
      coordinate_source: "geoapify"
    )
    sign_in_as(@admin)

    patch api_v1_location_path(location), params: { location: { name: "New Beach" } }

    assert_response :success
    location.reload
    assert_nil location.latitude
    assert_nil location.longitude
    assert_nil location.coordinate_source
    assert_equal "not_requested", location.geocoding_status
  end

  test "changing an address does not clear manual coordinates" do
    location = Location.create!(
      name: "Old Beach",
      locality: "Sydney",
      country_code: "AU",
      latitude: -33.9,
      longitude: 151.2,
      geocoding_status: "manual",
      coordinate_source: "manual"
    )
    sign_in_as(@admin)

    patch api_v1_location_path(location), params: { location: { name: "New Beach" } }

    assert_response :success
    location.reload
    assert_equal BigDecimal("-33.9"), location.latitude
    assert_equal "manual", location.coordinate_source
    assert_equal "manual", location.geocoding_status
  end

  test "verified locations can be listed by search with the attach filters applied" do
    Location.create!(name: "Pending Beach")
    sign_in_as(@player)

    # The organisation attach picker combines a search (which joins aliases)
    # with the verification and status filters and the ownership scope. The
    # combination must not raise, and must exclude anything unverified.
    get api_v1_locations_path, params: {
      q: "coogee",
      verification_status: "verified",
      status: "active"
    }

    assert_response :success
    ids = response.parsed_body.fetch("locations").map { |row| row.fetch("id") }
    assert_equal [ @verified.id ], ids
  end

  test "the attach filters exclude proposals and archived locations" do
    archived = Location.create!(
      name: "Old Beach",
      verification_status: "verified",
      verified_at: Time.current,
      verified_by_account: @admin.account,
      status: "archived"
    )
    sign_in_as(@player)

    get api_v1_locations_path, params: {
      verification_status: "verified",
      status: "active"
    }

    assert_response :success
    ids = response.parsed_body.fetch("locations").map { |row| row.fetch("id") }
    assert_includes ids, @verified.id
    assert_not_includes ids, archived.id
  end

  private

  def with_geocoding_config
    previous_enabled = ENV["GEOCODING_ENABLED"]
    previous_key = ENV["GEOAPIFY_API_KEY"]
    ENV["GEOCODING_ENABLED"] = "true"
    ENV["GEOAPIFY_API_KEY"] = "test-key"
    yield
  ensure
    ENV["GEOCODING_ENABLED"] = previous_enabled
    ENV["GEOAPIFY_API_KEY"] = previous_key
  end
end
