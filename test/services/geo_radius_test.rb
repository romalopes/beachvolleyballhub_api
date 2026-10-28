require "test_helper"

# The radius filter has no PostGIS or earthdistance to lean on, so the two
# pieces that decide which rows the SQL may consider are pinned here: the
# bounding box (cheap prefilter) and the parameter validation.
class GeoRadiusTest < ActiveSupport::TestCase
  test "bounding box brackets the radius around the point" do
    min_latitude, max_latitude, min_longitude, max_longitude =
      GeoRadius.bounding_box(-33.9, 151.2, 25)

    # 25 km is ~0.225 degrees of latitude.
    assert_in_delta(-34.1246, min_latitude, 0.001)
    assert_in_delta(-33.6754, max_latitude, 0.001)
    # A degree of longitude is shorter at this latitude, so the span is wider.
    assert_in_delta(150.9294, min_longitude, 0.001)
    assert_in_delta(151.4706, max_longitude, 0.001)
  end

  test "bounding box widens the longitude span near the poles without leaving the globe" do
    min_latitude, max_latitude, min_longitude, max_longitude =
      GeoRadius.bounding_box(89.999, 0, 25)

    assert_operator min_latitude, :>=, -90.0
    assert_operator max_latitude, :<=, 90.0
    assert_equal(-180.0, min_longitude)
    assert_equal 180.0, max_longitude
  end

  test "point ignores an absent filter and coerces a complete one" do
    assert_nil GeoRadius.point(nil, nil, nil)
    assert_nil GeoRadius.point("", "", "")
    # A partial triple is not a filter — it must not match nothing by accident.
    assert_nil GeoRadius.point(-33.9, nil, nil)
    assert_nil GeoRadius.point(-33.9, 151.2, nil)

    assert_equal [ -33.9, 151.2, 25.0 ], GeoRadius.point("-33.9", "151.2", "25")
  end

  test "point rejects unusable values" do
    assert_nil GeoRadius.point(91, 151.2, 25)
    assert_nil GeoRadius.point(-33.9, 181, 25)
    assert_nil GeoRadius.point(-33.9, 151.2, 0)
    assert_nil GeoRadius.point(-33.9, 151.2, -5)
    assert_nil GeoRadius.point("north", 151.2, 25)
  end

  test "errors explain unusable parameters and stay quiet otherwise" do
    assert_empty GeoRadius.errors_for(nil, nil, nil)
    assert_empty GeoRadius.errors_for("-33.9", "151.2", "25")

    assert_equal [ "latitude, longitude and radius_km must be provided together" ],
                 GeoRadius.errors_for(-33.9, nil, nil)
    assert_equal [ "latitude must be a number between -90 and 90" ],
                 GeoRadius.errors_for(91, 151.2, 25)
    assert_equal [ "longitude must be a number between -180 and 180" ],
                 GeoRadius.errors_for(-33.9, 181, 25)
    assert_equal [ "radius_km must be a positive number" ],
                 GeoRadius.errors_for(-33.9, 151.2, 0)
  end
end
