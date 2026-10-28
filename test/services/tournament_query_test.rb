require 'test_helper'

# Locks in the subquery filters (letter_levels, division_numbers, mine) that
# previously called an undefined `EXISTS(...)` helper and raised NoMethodError.
class TournamentQueryTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Query Org', acronym: 'QO')
    @account = create_account!

    @letter_tournament = Tournament.create!(
      name: 'Letter Tournament',
      organisation: @organisation,
      created_by_account: @account,
      scope: 'club',
      division_scheme: 'letter',
      publication_state: 'active',
      starts_at: 1.day.from_now,
      ends_at: 2.days.from_now,
      timezone: 'UTC',
      all_day: false
    )
    @letter_tournament.divisions.create!(letter_level: 'A', active: true)
    @letter_tournament.divisions.create!(letter_level: 'B', active: false)

    @numbered_tournament = Tournament.create!(
      name: 'Numbered Tournament',
      organisation: @organisation,
      created_by_account: @account,
      scope: 'club',
      division_scheme: 'numbered',
      publication_state: 'active',
      starts_at: 3.days.from_now,
      ends_at: 4.days.from_now,
      timezone: 'UTC',
      all_day: false
    )
    @numbered_tournament.divisions.create!(division_number: 1, active: true)
  end

  test 'filters by active letter level' do
    assert_includes TournamentQuery.call(letter_levels: ['A']).map(&:id), @letter_tournament.id
    # B exists but is inactive, so it must not match.
    assert_not_includes TournamentQuery.call(letter_levels: ['B']).map(&:id), @letter_tournament.id
  end

  test 'filters by division number' do
    assert_includes TournamentQuery.call(division_numbers: [1]).map(&:id), @numbered_tournament.id
    assert_not_includes TournamentQuery.call(division_numbers: [2]).map(&:id), @numbered_tournament.id
  end

  test 'filters by any selected organisation id' do
    other_organisation = Organisation.create!(name: 'Other Query Org', acronym: 'OQO')
    other_tournament = Tournament.create!(
      name: 'Other Organisation Tournament',
      organisation: other_organisation,
      created_by_account: @account,
      scope: 'club',
      division_scheme: 'letter',
      publication_state: 'active',
      starts_at: 5.days.from_now,
      ends_at: 6.days.from_now,
      timezone: 'UTC',
      all_day: false
    )

    ids = TournamentQuery.call(organisation_ids: [@organisation.id, other_organisation.id]).map(&:id)

    assert_includes ids, @letter_tournament.id
    assert_includes ids, other_tournament.id
  end

  test 'mine filter scopes to the account participations' do
    TournamentParticipation.create!(account: @account, tournament: @letter_tournament, role: 'player')

    ids = TournamentQuery.call(mine: true, account_id: @account.id).map(&:id)
    assert_includes ids, @letter_tournament.id
    assert_not_includes ids, @numbered_tournament.id
  end

  test "radius filter keeps only tournaments whose venue is inside the circle" do
    near = tournament_at(
      verified_location!("Coogee Beach", latitude: -33.9205, longitude: 151.2580),
      "Near Tournament", 7
    )
    # Inside the 25 km bounding box (0.2203° of latitude, 0.2665° of longitude)
    # but ~34.7 km away, so only the haversine term can reject it.
    corner = tournament_at(
      verified_location!("Box Corner Beach", latitude: -34.14, longitude: 151.525),
      "Corner Tournament", 8
    )

    ids = TournamentQuery.call(latitude: -33.9197, longitude: 151.2585, radius_km: 25).map(&:id)

    assert_includes ids, near.id
    assert_not_includes ids, corner.id
  end

  test "radius filter excludes a venue without canonical coordinates" do
    text_only = Tournament.create!(
      name: "Text Venue Tournament",
      organisation: @organisation,
      created_by_account: @account,
      location_name: "Somewhere Beach",
      scope: "club",
      division_scheme: "letter",
      publication_state: "active",
      starts_at: 9.days.from_now,
      ends_at: 10.days.from_now,
      timezone: "UTC",
      all_day: false
    )

    ids = TournamentQuery.call(latitude: -33.9197, longitude: 151.2585, radius_km: 25).map(&:id)

    assert_not_includes ids, text_only.id
  end

  test "radius filter is ignored while the parameters are incomplete" do
    ids = TournamentQuery.call(latitude: -33.9197).map(&:id)

    assert_includes ids, @letter_tournament.id
  end

  private

  # Only verified locations may be attached to a tournament, and only located
  # ones can be measured by the radius filter.
  def verified_location!(name, latitude:, longitude:)
    Location.create!(
      name: name,
      latitude: latitude,
      longitude: longitude,
      verification_status: "verified",
      verified_at: Time.current,
      source: "test"
    )
  end

  def tournament_at(location, name, days_from_now)
    Tournament.create!(
      name: name,
      organisation: @organisation,
      created_by_account: @account,
      location: location,
      scope: "club",
      division_scheme: "letter",
      publication_state: "active",
      starts_at: days_from_now.days.from_now,
      ends_at: (days_from_now + 1).days.from_now,
      timezone: "UTC",
      all_day: false
    )
  end
end
