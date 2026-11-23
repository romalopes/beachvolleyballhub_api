require "test_helper"

class AnalysisPackageTest < ActiveSupport::TestCase
  test "valid package" do
    package = AnalysisPackage.new(
      key: "test_package",
      name: "Test Package",
      price_cents: 4900,
      max_videos: 1,
      max_duration_minutes: 60,
      turnaround_days: 7
    )
    assert package.valid?
  end

  test "price_cents must be non-negative" do
    package = AnalysisPackage.new(key: "test", name: "Test", price_cents: -100, max_videos: 1, max_duration_minutes: 60, turnaround_days: 7)
    assert_not package.valid?
    assert_includes package.errors[:price_cents], "must be greater than or equal to 0"
  end

  test "max_videos must be positive" do
    package = AnalysisPackage.new(key: "test", name: "Test", price_cents: 4900, max_videos: 0, max_duration_minutes: 60, turnaround_days: 7)
    assert_not package.valid?
  end

  test "key must be unique" do
    AnalysisPackage.create!(key: "duplicate", name: "Test 1", price_cents: 4900, max_videos: 1, max_duration_minutes: 60, turnaround_days: 7)
    package = AnalysisPackage.new(key: "duplicate", name: "Test 2", price_cents: 4900, max_videos: 1, max_duration_minutes: 60, turnaround_days: 7)
    assert_not package.valid?
  end

  test "price_aud formats correctly" do
    package = AnalysisPackage.new(price_cents: 4900)
    assert_equal "$49.00 AUD", package.price_aud

    package = AnalysisPackage.new(price_cents: 0)
    assert_equal "Complimentary", package.price_aud

    package = AnalysisPackage.new(price_cents: 19900)
    assert_equal "$199.00 AUD", package.price_aud
  end

  test "active scope returns only active packages ordered by position" do
    # Uses fixtures: complimentary (pos 0), single_match (pos 1), season_review (pos 2), inactive (pos 3, inactive)
    active = AnalysisPackage.active
    assert_equal 3, active.count
    assert_equal "complimentary", active.first.key
    assert_equal "single_match", active.second.key
    assert_equal "season_review", active.third.key
    assert_not_includes active.map(&:key), "inactive"
  end
end