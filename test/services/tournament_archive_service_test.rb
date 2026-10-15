require 'test_helper'

class TournamentArchiveServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Test Org', acronym: 'TO')
    @account = create_account!
    @tournament = Tournament.create!(
      name: 'Tournament to Archive',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :active
    )
  end

  test 'should archive a tournament' do
    archived_tournament = TournamentArchiveService.call(@tournament)

    assert archived_tournament.persisted?
    assert_equal 'archived', archived_tournament.publication_state
  end

  test 'should allow archiving from any state' do
    [:draft, :active, :cancelled].each do |state|
      tournament = Tournament.create!(
        name: "Tournament #{state}",
        organisation_id: @organisation.id,
        created_by_account_id: @account.id,
        scope: 'club',
        division_scheme: 'letter',
        starts_at: '2026-10-15 09:00:00',
        ends_at: '2026-10-15 17:00:00',
        timezone: 'US/Eastern',
        all_day: false,
        publication_state: state
      )

      archived = TournamentArchiveService.call(tournament)
      assert_equal 'archived', archived.publication_state
    end
  end

  test 'should raise error if tournament is invalid' do
    # Make the tournament invalid by removing the name
    @tournament.name = nil
    # We cannot save because of validation, but we can still try to call the service
    # The service will try to save and fail due to validation
    assert_raises ActiveRecord::RecordInvalid do
      TournamentArchiveService.call(@tournament)
    end
  end
end