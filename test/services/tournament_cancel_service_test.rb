require 'test_helper'

class TournamentCancelServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Cancel Org', acronym: 'CO')
    @account = create_account!
    @tournament = Tournament.create!(
      name: 'Cancel Me',
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

  test 'cancels an active tournament' do
    cancelled = TournamentCancelService.call(@tournament)

    assert cancelled.persisted?
    assert_equal 'cancelled', cancelled.publication_state
    assert_equal 'cancelled', @tournament.reload.publication_state
  end

  test 'cancels a draft tournament' do
    @tournament.update!(publication_state: :draft)

    TournamentCancelService.call(@tournament)

    assert_equal 'cancelled', @tournament.reload.publication_state
  end

  test 'is idempotent for an already cancelled tournament' do
    @tournament.update!(publication_state: :cancelled)

    cancelled = TournamentCancelService.call(@tournament)

    assert_equal 'cancelled', cancelled.publication_state
  end

  test 'refuses to cancel an archived tournament until it is restored' do
    @tournament.update!(publication_state: :archived)

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentCancelService.call(@tournament)
    end

    assert_match(/restored/, error.message)
    assert_equal 'archived', @tournament.reload.publication_state
  end
end
