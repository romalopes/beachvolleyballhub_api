# Shared "within N km of a point" geography for the event calendars.
#
# Neither PostGIS nor the earthdistance extension is installed, so distances
# are derived from the plain `locations.latitude` / `locations.longitude`
# columns: a bounding box on those columns narrows the candidate set (cheap,
# and index-friendly if an index is ever added), then a haversine term keeps
# only the rows inside the true circle.
#
# Callers join `locations` themselves, so the SQL below refers to that table
# by name. Rows whose location has no coordinates cannot be measured, so the
# filter excludes them rather than guessing.
module GeoRadius
  # Mean Earth radius in kilometres (IUGG mean radius).
  EARTH_RADIUS_KM = 6371.0
  # A degree of latitude is ~111.32 km everywhere. A degree of longitude is
  # shorter towards the poles, so its delta is scaled by cos(latitude).
  KM_PER_DEGREE_LATITUDE = 111.32
  # A near-polar point would otherwise ask for a longitude span wider than the
  # globe; clamping keeps the box a valid BETWEEN range.
  MAX_LONGITUDE_DELTA = 180.0

  # Great-circle distance predicate, in kilometres. The bind order is:
  # latitude, latitude, longitude, radius_km.
  HAVERSINE_DISTANCE_SQL = <<~SQL.squish.freeze
    #{EARTH_RADIUS_KM} * 2 * asin(sqrt(
      power(sin(radians(locations.latitude - ?) / 2), 2) +
      cos(radians(?)) * cos(radians(locations.latitude)) *
      power(sin(radians(locations.longitude - ?) / 2), 2)
    )) <= ?
  SQL

  module_function

  # Latitude/longitude bounds bracketing a radius around a point, ordered the
  # way BETWEEN expects them: min_latitude, max_latitude, min_longitude,
  # max_longitude.
  def bounding_box(latitude, longitude, radius_km)
    latitude_delta = radius_km / KM_PER_DEGREE_LATITUDE
    longitude_delta = [
      radius_km / (KM_PER_DEGREE_LATITUDE * Math.cos(latitude * Math::PI / 180).abs),
      MAX_LONGITUDE_DELTA
    ].min

    [
      [ latitude - latitude_delta, -90.0 ].max,
      [ latitude + latitude_delta, 90.0 ].min,
      [ longitude - longitude_delta, -180.0 ].max,
      [ longitude + longitude_delta, 180.0 ].min
    ]
  end

  # The three parameters as floats, or nil when the filter is not usable.
  # They travel together: a partial or malformed triple is ignored rather than
  # silently matching nothing.
  def point(latitude, longitude, radius_km)
    return nil if [ latitude, longitude, radius_km ].any?(&:blank?)
    return nil if errors_for(latitude, longitude, radius_km).any?

    [ Float(latitude), Float(longitude), Float(radius_km) ]
  end

  # Human-readable problems with the radius parameters, so both calendars
  # reject unusable input with the same wording instead of a database error.
  # An empty array means either "no filter" or "a usable filter".
  def errors_for(latitude, longitude, radius_km)
    values = [ latitude, longitude, radius_km ]
    return [] if values.all?(&:blank?)
    return [ "latitude, longitude and radius_km must be provided together" ] if values.any?(&:blank?)

    errors = []
    errors << "latitude must be a number between -90 and 90" unless within?(latitude, -90, 90)
    errors << "longitude must be a number between -180 and 180" unless within?(longitude, -180, 180)
    errors << "radius_km must be a positive number" unless positive?(radius_km)
    errors
  end

  def within?(value, minimum, maximum)
    number = Float(value)
    number >= minimum && number <= maximum
  rescue ArgumentError, TypeError
    false
  end

  def positive?(value)
    Float(value).positive?
  rescue ArgumentError, TypeError
    false
  end
end
