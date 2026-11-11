require "test_helper"

class WeatherShareSnapshotTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "generates a unique public_token on create" do
    snapshot = create_snapshot!

    assert snapshot.public_token.present?
    assert_equal 32, snapshot.public_token.length
    assert snapshot.valid?
  end

  test "public_token is unique" do
    existing = create_snapshot!
    duplicate = WeatherShareSnapshot.new(
      account: @account,
      public_token: existing.public_token,
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Another Location",
      weather_data: { current: {}, forecast: [], hourly: [] }
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :public_token
  end

  test "sets default expiry of 7 days" do
    freeze_time do
      snapshot = create_snapshot!

      assert_in_delta 7.days.from_now, snapshot.expires_at, 1.second
    end
  end

  test "allows custom expiry" do
    freeze_time do
      snapshot = create_snapshot!(expires_at: 30.days.from_now)

      assert_in_delta 30.days.from_now, snapshot.expires_at, 1.second
    end
  end

  test "active? returns true for non-revoked, non-expired snapshot" do
    snapshot = create_snapshot!

    assert_predicate snapshot, :active?
  end

  test "active? returns false for expired snapshot" do
    freeze_time do
      snapshot = create_snapshot!(expires_at: 1.day.ago)

      assert_not snapshot.active?
      assert_predicate snapshot, :expired?
    end
  end

  test "active? returns false for revoked snapshot" do
    snapshot = create_snapshot!
    snapshot.revoke!

    assert_not snapshot.active?
    assert_predicate snapshot, :revoked?
  end

  test "revoke! sets revoked_at timestamp" do
    snapshot = create_snapshot!
    freeze_time { snapshot.revoke! }

    assert_in_delta Time.current, snapshot.revoked_at, 1.second
  end

  test "public_url returns frontend URL for active snapshot" do
    snapshot = create_snapshot!

    expected = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5174')}/weather/#{snapshot.public_token}"
    assert_equal expected, snapshot.public_url
  end

  test "public_url removes a trailing slash from frontend URL" do
    snapshot = create_snapshot!

    original_frontend_url = ENV["FRONTEND_URL"]
    ENV["FRONTEND_URL"] = "https://example.com/"

    begin
      assert_equal "https://example.com/weather/#{snapshot.public_token}", snapshot.public_url
    ensure
      ENV["FRONTEND_URL"] = original_frontend_url
    end
  end

  test "public_url returns nil for expired snapshot" do
    snapshot = create_snapshot!(expires_at: 1.day.ago)

    assert_nil snapshot.public_url
  end

  test "public_url returns nil for revoked snapshot" do
    snapshot = create_snapshot!
    snapshot.revoke!

    assert_nil snapshot.public_url
  end

  private

  def create_snapshot!(overrides = {})
    @account.weather_share_snapshots.create!({
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [], hourly: [] },
      volleyball_score: 75,
      volleyball_label: "Good",
      volleyball_warnings: [],
      volleyball_advice: [],
      volleyball_safety_override: false
    }.merge(overrides))
  end

  def snapshot_row(timestamp:, **overrides)
    {
      account_id: @account.id,
      public_token: SecureRandom.urlsafe_base64(24),
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [], hourly: [] }.to_json,
      volleyball_score: 75,
      volleyball_label: "Good",
      volleyball_warnings: [].to_json,
      volleyball_advice: [].to_json,
      volleyball_safety_override: false,
      expires_at: 7.days.from_now,
      created_at: timestamp,
      updated_at: timestamp
    }.merge(overrides)
  end
end