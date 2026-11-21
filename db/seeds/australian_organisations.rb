# Idempotent seed for the main beach volleyball organisations of Australia,
# including a few unofficial/community groups.
#
# Run with:
#   bin/rails runner db/seeds/australian_organisations.rb
#
# Locations are created as active + verified so they satisfy
# OrganisationLocation#location_is_selectable (must be selectable).
# Verification provenance is supplied via `source: "seed"` so no account
# is required.

# ---------------------------------------------------------------------------
# Locations (Sydney beaches)
# ---------------------------------------------------------------------------

location_data = [
  {
    name: "Coogee Beach",
    locality: "Coogee",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.9223,
    longitude: 151.2530,
    notes: "Popular ocean beach in Sydney's eastern suburbs, home of CBVA.",
  },
  {
    name: "Manly Beach",
    locality: "Manly",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.7970,
    longitude: 151.2868,
    notes: "Iconic northern beaches surf spot, hub for NBVA and Manly beach volleyball.",
  },
  {
    name: "Maroubra Beach",
    locality: "Maroubra",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.9500,
    longitude: 151.2447,
    notes: "Eastern suburbs beach known for its long swell and local volleyball scene.",
  },
  {
    name: "Bondi Beach",
    locality: "Bondi",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.8915,
    longitude: 151.2757,
    notes: "World-famous beach with an active casual volleyball community.",
  },
  {
    name: "Tamarama Beach",
    locality: "Tamarama",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.8999,
    longitude: 151.2699,
    notes: "Small beach between Bondi and Bronte, popular with locals.",
  },
  {
    name: "Clovelly Beach",
    locality: "Clovelly",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.91322,
    longitude: 151.2659,
    notes: "Protected bay beach between Coogee and Bronte, good for beginners.",
  },
  {
    name: "Brighton Le Sands Beach",
    locality: "Brighton Le Sands",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.9428,
    longitude: 151.1706,
    notes: "Beach on Botany Bay in Sydney's southern suburbs, popular for kitesurfing and casual volleyball.",
  },
  {
    name: "Blacktown City Beach Volleyball Courts",
    locality: "Blacktown",
    administrative_area: "NSW",
    country_code: "AU",
    latitude: -33.7322,
    longitude: 150.9324,
    notes: "Dedicated beach volleyball courts in Sydney's western suburbs, operated by Blacktown City Beach Volleyball.",
  },
  {
    name: "St Kilda Beach",
    locality: "St Kilda",
    administrative_area: "VIC",
    country_code: "AU",
    latitude: -37.8664,
    longitude: 144.9686,
    notes: "Melbourne's iconic bayside beach, home of Vic Beach and the Victorian beach volleyball scene.",
  },
  {
    name: "Surfers Paradise Beach",
    locality: "Surfers Paradise",
    administrative_area: "QLD",
    country_code: "AU",
    latitude: -28.0021,
    longitude: 153.4279,
    notes: "Gold Coast's famous beach, hub of Queensland beach volleyball.",
  },
  {
    name: "Cottesloe Beach",
    locality: "Cottesloe",
    administrative_area: "WA",
    country_code: "AU",
    latitude: -31.9989,
    longitude: 115.7518,
    notes: "Perth's popular beach with dedicated volleyball courts, home of Hub Beach Volleyball.",
  },
].freeze

locations = {}
location_data.each do |attrs|
  notes = attrs.delete(:notes)
  locations[attrs[:name]] = Location.find_or_create_by!(name: attrs[:name]) do |loc|
    loc.location_type = "beach"
    loc.status = "active"
    loc.verification_status = "verified"
    loc.geocoding_status = "resolved"
    loc.coordinate_source = "manual"
    loc.source = "seed"
    loc.verified_at = Time.current
    loc.normalized_name = Location.normalize_name(attrs[:name])
    loc.formatted_address = "#{attrs[:name]}, #{attrs[:locality]}, #{attrs[:administrative_area]}, Australia"
    loc.country_code = attrs[:country_code]
    loc.latitude = attrs[:latitude]
    loc.longitude = attrs[:longitude]
    loc.internal_notes = notes
  end
  locations[attrs[:name]].update!(
    internal_notes: notes,
    status: "active",
    verification_status: "verified",
  )
end

puts "Seeded #{locations.size} locations"

# ---------------------------------------------------------------------------
# Organisations
# ---------------------------------------------------------------------------

org_data = [
  {
    name: "Volleyball NSW",
    acronym: "VNSW",
    organisation_type: "state_federation",
    description: "The state body for New South Wales, governing beach volleyball across the state.",
    website: "https://www.volleyballnsw.com.au/",
  },
  {
    name: "Coogee Beach Volleyball Association",
    acronym: "CBVA",
    organisation_type: "association",
    description: "Community beach volleyball association based at Coogee Beach, Sydney.",
    location_name: "Coogee Beach",
    website: "https://cbva.org.au",
    parent_name: "Volleyball NSW",
  },
  {
    name: "Northern Beaches Volleyball Association",
    acronym: "NBVA",
    organisation_type: "association",
    description: "Association serving the northern beaches region, based at Manly Beach.",
    location_name: "Manly Beach",
    website: "https://nbva.org.au",
    parent_name: "Volleyball NSW",
  },
  {
    name: "BeachVolleyball.com (Maroubra)",
    acronym: "BVC-MB",
    organisation_type: "club",
    description: "Commercial beach volleyball operation at Maroubra Beach.",
    location_name: "Maroubra Beach",
    website: "https://beachvolleyball.org.au",
  },
  {
    name: "BeachVolleyball.com (Manly)",
    acronym: "BVC-MN",
    organisation_type: "club",
    description: "Commercial beach volleyball operation at Manly Beach.",
    location_name: "Manly Beach",
    website: "https://beachvolleyball.org.au",
  },
  {
    name: "Brighton Beach Volleyball Association",
    acronym: "BBVA",
    organisation_type: "club",
    description: "Association serving the Brighton region, based at Brighton Beach.",
    location_name: "Brighton Le Sands Beach",
    website: "https://bbva.org.au",
    parent_name: "Volleyball NSW",
  },
  {
    name: "Beach Volleyball in Bondi",
    acronym: "BVB",
    organisation_type: "other",
    description: "Unofficial community group running casual games at Bondi Beach.",
    location_name: "Bondi Beach",
    website: nil,
  },
  {
    name: "Beach Volleyball in Clovelly",
    acronym: "CVB",
    organisation_type: "other",
    description: "Unofficial community group running casual games at Clovelly Beach.",
    location_name: "Clovelly Beach",
    website: nil,
  },
  {
    name: "Beach Volleyball in Tamarama",
    acronym: "TVB",
    organisation_type: "other",
    description: "Unofficial community group running casual games at Tamarama Beach.",
    location_name: "Tamarama Beach",
    website: nil,
  },
  {
    name: "Blacktown City Beach Volleyball",
    acronym: "BCBV",
    organisation_type: "club",
    description: "Dedicated beach volleyball club operating courts in Sydney's western suburbs.",
    location_name: "Blacktown City Beach Volleyball Courts",
    website: nil,
    parent_name: "Volleyball NSW",
  },
  {
    name: "Volleyball Victoria",
    acronym: "VV",
    organisation_type: "state_federation",
    description: "The state body for Victoria, governing beach volleyball across the state.",
    website: "https://volleyballvictoria.org.au/",
  },
  {
    name: "Vic Beach",
    acronym: "VB",
    organisation_type: "club",
    description: "Victoria's premier beach volleyball club, based at St Kilda Beach in Melbourne.",
    location_name: "St Kilda Beach",
    website: "https://vicbeach.com.au/",
    parent_name: "Volleyball Victoria",
  },
  {
    name: "Volleyball Queensland",
    acronym: "VQ",
    organisation_type: "state_federation",
    description: "The state body for Queensland, governing beach volleyball across the state.",
    website: "https://vq.org.au/",
  },
  {
    name: "Beach Volleyball Gold Coast",
    acronym: "BVGC",
    organisation_type: "club",
    description: "Queensland's leading beach volleyball club, based at Surfers Paradise Beach on the Gold Coast.",
    location_name: "Surfers Paradise Beach",
    website: "https://beachvolleyballgoldcoast.com/",
    parent_name: "Volleyball Queensland",
  },
  {
    name: "Volleyball WA",
    acronym: "VWA",
    organisation_type: "state_federation",
    description: "The state body for Western Australia, governing beach volleyball across the state.",
    website: "https://volleyballwa.com.au/",
  },
  {
    name: "Hub Beach Volleyball",
    acronym: "HBV",
    organisation_type: "club",
    description: "Perth's dedicated beach volleyball club, based at Cottesloe Beach in Western Australia.",
    location_name: "Cottesloe Beach",
    website: "https://hubvolleyball.com.au/",
    parent_name: "Volleyball WA",
  },
  {
    name: "Sydney University Beach Volleyball Club",
    acronym: "SUBC",
    organisation_type: "club",
    description: "University beach volleyball club based at various Sydney beaches.",
    location_name: "Manly Beach",
    website: "https://sunc.org.au/beach-volleyball",
    parent_name: "Volleyball NSW",
  },
  {
    name: "Melbourne University Beach Volleyball Club",
    acronym: "MUVC",
    organisation_type: "club",
    description: "Melbourne university beach volleyball club, training at St Kilda and Brighton beaches.",
    location_name: "St Kilda Beach",
    website: "https://mubs.com.au/",
    parent_name: "Volleyball Victoria",
  },
  {
    name: "Gold Coast University Beach Volleyball",
    acronym: "GCUVB",
    organisation_type: "club",
    description: "University beach volleyball club representing Gold Coast students.",
    location_name: "Surfers Paradise Beach",
    website: "https://gcubvolleyball.com/",
    parent_name: "Volleyball Queensland",
  },
].freeze

organisations = {}
org_data.each do |attrs|
  loc_name = attrs.delete(:location_name)
  parent_name = attrs.delete(:parent_name)
  org = Organisation.find_or_create_by!(name: attrs[:name]) do |o|
    o.acronym = attrs[:acronym]
    o.organisation_type = attrs[:organisation_type]
    o.description = attrs[:description]
    o.status = "active"
    o.website = attrs[:website]
  end
  org.update!(
    acronym: attrs[:acronym],
    organisation_type: attrs[:organisation_type],
    description: attrs[:description],
    website: attrs[:website],
  )
  organisations[attrs[:name]] = { org: org, parent_name: parent_name, location_name: loc_name }
end

# Set parent_organisation for organisations that have a parent
organisations.each do |name, data|
  next if data[:parent_name].nil?
  parent = organisations.fetch(data[:parent_name])[:org]
  data[:org].update!(parent_organisation: parent) if data[:org].parent_organisation_id.nil?
end

puts "Seeded #{organisations.size} organisations"

# ---------------------------------------------------------------------------
# Link organisations to their locations
# ---------------------------------------------------------------------------

organisations.each do |name, data|
  next if data[:location_name].nil?
  org = data[:org]
  loc = locations.fetch(data[:location_name])

  OrganisationLocation.find_or_create_by!(organisation: org, location: loc)

  # Set the default location on first-run only if not already set
  org.update!(default_location: loc) if org.default_location_id.nil?
end

puts "Linked #{organisations.count { |_, d| d[:location_name] }} organisations to their locations"
puts "Australian organisations seeding complete"