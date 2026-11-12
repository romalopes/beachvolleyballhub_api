require "test_helper"

class WeatherShareImageGeneratorJobTest < ActiveJob::TestCase
  test "generates an image for an active snapshot" do
    snapshot = users(:five).account.weather_share_snapshots.create!(
      latitude: -33.8688,
      longitude: 151.2093,
      location_name: "Bondi Beach",
      weather_data: { current: {}, forecast: [] },
      volleyball_score: 85,
      volleyball_label: "Excellent",
      volleyball_warnings: [],
      volleyball_advice: [],
      volleyball_safety_override: false
    )

    generated_snapshot = nil
    original_generate_for = WeatherShareImageGenerator.method(:generate_for)
    WeatherShareImageGenerator.define_singleton_method(:generate_for) do |record|
      generated_snapshot = record
    end
    WeatherShareImageGeneratorJob.perform_now(snapshot)

    assert_equal snapshot, generated_snapshot
  ensure
    WeatherShareImageGenerator.define_singleton_method(:generate_for, original_generate_for) if original_generate_for
  end
end
