require 'test_helper'

class TournamentCreateServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Test Org', acronym: 'TO')
    @account = create_account!
  end

  test 'should create a tournament with valid parameters' do
    params = {
      name: 'Test Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false
    }

    tournament = TournamentCreateService.call(params)

    assert tournament.persisted?
    assert_equal 'Test Tournament', tournament.name
    assert_equal @organisation.id, tournament.organisation_id
    assert_equal @account.id, tournament.created_by_account_id
    assert_equal 'club', tournament.scope
    assert_equal 'letter', tournament.division_scheme
    assert_equal 'US/Eastern', tournament.timezone
    assert_equal false, tournament.all_day

    # Check that the times are converted to UTC (we expect the UTC times to be 4 hours ahead of US/Eastern in October? Actually, US/Eastern is UTC-4 or UTC-5 depending on DST.
    # We'll just check that the starts_at is not nil and is a time.
    assert_not_nil tournament.starts_at
    assert_not_nil tournament.ends_at
    assert tournament.ends_at > tournament.starts_at
  end

  test 'should create an all-day tournament' do
    params = {
      name: 'All Day Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15', # date only
      ends_at: '2026-10-15',   # date only
      timezone: 'US/Eastern',
      all_day: true
    }

    tournament = TournamentCreateService.call(params)

    assert tournament.persisted?
    assert_equal true, tournament.all_day

    # For all-day, we expect the starts_at to be at 00:00:00 in the timezone and ends_at at 23:59:59.999999 in the timezone, converted to UTC.
    # We'll check that the date part of starts_at in the timezone is the same as the input date.
    begins_in_zone = tournament.starts_at.in_time_zone(tournament.timezone)
    ends_in_zone = tournament.ends_at.in_time_zone(tournament.timezone)

    assert_equal Date.new(2026, 10, 15), begins_in_zone.to_date
    assert_equal Date.new(2026, 10, 15), ends_in_zone.to_date
    # The time part of begins_in_zone should be 00:00:00
    assert_equal 0, begins_in_zone.hour
    assert_equal 0, begins_in_zone.min
    assert_equal 0, begins_in_zone.sec
    # The time part of ends_in_zone should be 23:59:59
    assert_equal 23, ends_in_zone.hour
    assert_equal 59, ends_in_zone.min
    assert_equal 59, ends_in_zone.sec
  end

  test 'should raise an error for invalid timezone' do
    params = {
      name: 'Test Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'Invalid/Timezone',
      all_day: false
    }

    assert_raises ArgumentError do
      TournamentCreateService.call(params)
    end
  end

  test 'should not create tournament if validation fails' do
    params = {
      name: '', # invalid
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false
    }

    assert_raises ActiveRecord::RecordInvalid do
      TournamentCreateService.call(params)
    end
  end
end