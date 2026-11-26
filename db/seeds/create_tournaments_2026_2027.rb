# Seeding file to create tournaments from beachvolleyballhub_tournaments_2026_2027.json
# Ensures organisations and locations exist (creating/approving if missing)
# Creates tournaments and reports what wasn't uploaded
# Run with:
#   bin/rails runner db/seeds/create_tournaments_2026_2027.rb

require 'json'

json_path = Rails.root.join('db', 'seeds', 'beachvolleyballhub_tournaments_2026_2027.json')
data = JSON.parse(File.read(json_path))
tournaments_data = data['tournaments'] || []

created_tournaments = []
failed_tournaments = []
org_names = tournaments_data.map { |t| t['organisation']['name'] }.uniq
loc_names = tournaments_data.map { |t| t['location_name'] }.uniq

# Organisation cache: name => Organisation object
organisation_cache = {}

# Location cache: name => Location object
location_cache = {}

# Step 1: Ensure organisations exist
org_names.each do |org_name|
  org = Organisation.find_or_create_by!(name: org_name) do |o|
    o.acronym = nil
    o.organisation_type = 'state_federation'
    o.description = "Organisation for #{org_name} beach volleyball tournaments"
    o.status = 'active'
    o.website = nil
  end
  organisation_cache[org_name] = org
end

# Step 2: Ensure locations exist and are approved
loc_names.each do |loc_name|
  # Guess administrative area from location name
  admin_area = case loc_name
               when /ACT|Canberra/ then 'ACT'
               when /NSW|Sydney/ then 'NSW'
               when /VIC|Melbourne/ then 'VIC'
               when /QLD|Brisbane/ then 'QLD'
               when /SA/ then 'SA'
               when /TAS/ then 'TAS'
               when /WA/ then 'WA'
               when /NT/ then 'NT'
               else 'NSW'
               end

  # Guess location type based on name patterns
  loc_type = case loc_name.downcase
             when /(beach|sand|shore)/i then 'beach'
             when /(venue|stadium|court)/i then 'sports_venue'
             when /(park)/i then 'park'
             else 'beach'
             end

  loc = Location.find_or_create_by!(name: loc_name) do |l|
    l.location_type = loc_type
    l.status = 'active'
    l.verification_status = 'verified'
    l.geocoding_status = 'resolved'
    l.country_code = 'AU'
    l.formatted_address = loc_name
    l.locality = loc_name
    l.administrative_area = admin_area
    l.timezone = case loc_name
                 when /Sydney|New South Wales/ then 'Australia/Sydney'
                 when /Melbourne|Victoria/ then 'Australia/Melbourne'
                 when /Brisbane|Queensland/ then 'Australia/Brisbane'
                 when /Adelaide|South Australia/ then 'Australia/Adelaide'
                 when /Perth|Western Australia/ then 'Australia/Perth'
                 when /Hobart|Tasmania/ then 'Australia/Hobart'
                 else 'Australia/Sydney'
                 end
    # Set latitude/longitude - both nil is valid (satisfies check constraint)
    l.latitude = nil
    l.longitude = nil
    # Set provenance for verified status (required by validation)
    l.source = 'seed'
    l.verified_at = Time.current
  end
  location_cache[loc_name] = loc
end

# Step 3: Create tournaments
# Get or create a test account for created_by_account
# The accounts table uses user_id, not email
# test_account = Account.find_by_user_id(1) || Account.create!(name: 'Seed User')

tournaments_data.each do |t|
  org_name = t['organisation']['name']
  loc_name = t['location_name']

  org = organisation_cache[org_name]
  loc = location_cache[loc_name]

  next unless org && loc

  # Use 'letter' as default division scheme if not specified (valid values: 'letter', 'numbered')
  division_scheme = t['division_scheme'] || 'letter'

  begin
    Tournament.create!(
      name: t['name'],
      organisation: org,
      location: loc,
      scope: t['scope'] || 'state',
      division_scheme: division_scheme,
      starts_at: t['starts_at'],
      ends_at: t['ends_at'],
      timezone: t['timezone'] || 'Australia/Sydney',
      publication_state: t['publication_state'] || 'active',
      website_url: t['website_url'],
      all_day: t['all_day'] || false,
      description: t['description'],
      created_by_account: Account.first
    )
    created_tournaments << t['name']
  rescue => e
    failed_tournaments << { name: t['name'], error: e.message, class: e.class.name }
  end
end

# Step 4: Report
puts "Created: #{created_tournaments.size}/#{tournaments_data.size}"
# puts "Failed: #{
#   failed_tournaments.map { |f| f[:name] }.join(', '
# )}" unless failed_tournaments.empty?
failed_tournaments.map { |f| puts "Failed to create tournament '#{f[:name]}': #{f[:error]} (#{f[:class]})" }
puts "Organisations ensured: #{org_names.size}"
puts "Locations ensured and approved: #{loc_names.size}"
puts "=== TOURNAMENT SEEDING COMPLETE ==="