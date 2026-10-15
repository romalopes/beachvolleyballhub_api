require 'test_helper'

class TournamentUpdateServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Test Org', acronym: 'TO')
    @account = create_account!
    @tournament = Tournament.create!(
      name: 'Original Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: 1.day.from_now,
      ends_at: 2.days.from_now,
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :draft
    )
  end

  test 'should update a tournament with valid parameters' do
    params = {
      name: 'Updated Tournament',
      scope: 'state',
      division_scheme: 'numbered',
      starts_at: '2026-10-16 10:00:00',
      ends_at: '2026-10-16 18:00:00',
      timezone: 'Europe/London',
      all_day: false
    }

    updated_tournament = TournamentUpdateService.call(@tournament, params)

    assert updated_tournament.persisted?
    assert_equal 'Updated Tournament', updated_tournament.name
    assert_equal 'state', updated_tournament.scope
    assert_equal 'numbered', updated_tournament.division_scheme
    assert_equal 'Europe/London', updated_tournament.timezone
    assert_equal false, updated_tournament.all_day

    # Check that the times are converted to UTC
    assert_not_nil updated_tournament.starts_at
    assert_not_nil updated_tournament.ends_at
    assert updated_tournament.ends_at > updated_tournament.starts_at
  end

  test 'should update to an all-day tournament' do
    params = {
      starts_at: '2026-10-16', # date only
      ends_at: '2026-10-16',   # date only
      timezone: 'Europe/London',
      all_day: true
    }

    updated_tournament = TournamentUpdateService.call(@tournament, params)

    assert updated_tournament.persisted?
    assert_equal true, updated_tournament.all_day

    # For all-day, we expect the starts_at to be at 00:00:00 in the timezone and ends_at at 23:59:59.999999 in the timezone, converted to UTC.
    begins_in_zone = updated_tournament.starts_at.in_time_zone(updated_tournament.timezone)
    ends_in_zone = updated_tournament.ends_at.in_time_zone(updated_tournament.timezone)

    assert_equal Date.new(2026, 10, 16), begins_in_zone.to_date
    assert_equal Date.new(2026, 10, 16), ends_in_zone.to_date
    assert_equal 0, begins_in_zone.hour
    assert_equal 0, begins_in_zone.min
    assert_equal 0, begins_in_zone.sec
    assert_equal 23, ends_in_zone.hour
    assert_equal 59, ends_in_zone.min
    assert_equal 59, ends_in_zone.sec
  end

  test 'should raise an error for invalid timezone' do
    params = {
      timezone: 'Invalid/Timezone'
    }

    assert_raises ArgumentError do
      TournamentUpdateService.call(@tournament, params)
    end
  end

  test 'should not update tournament if validation fails' do
    params = {
      name: '' # invalid
    }

    assert_raises ActiveRecord::RecordInvalid do
      TournamentUpdateService.call(@tournament, params)
    end
  end

  test 'should not change attributes not in params' do
    original_name = @tournament.name
    original_scope = @tournament.scope

    params = {
      description: 'New description'
    }

    updated_tournament = TournamentUpdateService.call(@tournament, params)

    assert_equal original_name, updated_tournament.name
    assert_equal original_scope, updated_tournament.scope
    assert_equal 'New description', updated_tournament.description
  end

  test 'refuses to change the division scheme once participation exists' do
    @tournament.update!(publication_state: :active)
    division = @tournament.divisions.create!(letter_level: 'A', active: true)
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [division.id]
    )

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentUpdateService.call(@tournament, division_scheme: 'numbered')
    end

    assert_match(/scheme cannot be changed/, error.message)
    assert_equal 'letter', @tournament.reload.division_scheme
  end

  test 're-asserting the current scheme with participation is allowed' do
    @tournament.update!(publication_state: :active)
    division = @tournament.divisions.create!(letter_level: 'A', active: true)
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [division.id]
    )

    updated = TournamentUpdateService.call(
      @tournament, division_scheme: 'letter', description: 'still letter'
    )

    assert_equal 'letter', updated.division_scheme
    assert_equal 'still letter', updated.description
  end
end