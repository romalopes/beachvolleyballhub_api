require 'test_helper'

class TournamentRestoreServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Restore Org', acronym: 'RO')
    @account = create_account!
    @tournament = Tournament.create!(
      name: 'Restore Me',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :archived
    )
  end

  test 'restores an archived tournament to draft' do
    restored = TournamentRestoreService.call(@tournament)

    assert_equal 'draft', restored.publication_state
    assert_equal 'draft', @tournament.reload.publication_state
  end

  test 'restores a cancelled tournament to draft' do
    @tournament.update!(publication_state: :cancelled)

    TournamentRestoreService.call(@tournament)

    assert_equal 'draft', @tournament.reload.publication_state
  end

  test 'restoring an active tournament is rejected' do
    @tournament.update!(publication_state: :active)

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentRestoreService.call(@tournament)
    end

    assert_match(/Only archived or cancelled/, error.message)
    assert_equal 'active', @tournament.reload.publication_state
  end

  test 'restoring a draft tournament is rejected' do
    @tournament.update!(publication_state: :draft)

    assert_raises ActiveRecord::RecordInvalid do
      TournamentRestoreService.call(@tournament)
    end
  end
end
