require 'test_helper'

class TournamentPublishServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Test Org', acronym: 'TO')
    @account = create_account!
  end

  test 'should publish a tournament with at least one active division' do
    tournament = Tournament.create!(
      name: 'Tournament to Publish',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :draft
    )

    # Create an active division
    tournament.divisions.create!(
      letter_level: 'A',
      active: true
    )

    published_tournament = TournamentPublishService.call(tournament)

    assert published_tournament.persisted?
    assert_equal :active, published_tournament.publication_state
  end

  test 'should not publish a tournament without any active division' do
    tournament = Tournament.create!(
      name: 'Tournament without Active Division',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :draft
    )

    # Create an inactive division
    tournament.divisions.create!(
      letter_level: 'B',
      active: false
    )

    assert_raises ActiveRecord::RecordInvalid do
      TournamentPublishService.call(tournament)
    end

    # Ensure the tournament is still draft
    assert_equal :draft, tournament.reload.publication_state
  end

  test 'should not publish a tournament with no divisions' do
    tournament = Tournament.create!(
      name: 'Tournament without Divisions',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :draft
    )

    assert_raises ActiveRecord::RecordInvalid do
      TournamentPublishService.call(tournament)
    end

    assert_equal :draft, tournament.reload.publication_state
  end

  test 'should raise error if tournament is invalid for other reasons' do
    tournament = Tournament.create!(
      name: 'Invalid Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 08:00:00', # ends before starts
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :draft
    )

    # Add an active division to pass the division check
    tournament.divisions.create!(
      letter_level: 'A',
      active: true
    )

    assert_raises ActiveRecord::RecordInvalid do
      TournamentPublishService.call(tournament)
    end

    assert_equal :draft, tournament.reload.publication_state
  end
end