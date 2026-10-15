require 'test_helper'

class TournamentDivisionServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Division Org', acronym: 'DO')
    @account = create_account!
    @tournament = Tournament.create!(
      name: 'Division Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-16 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :active
    )
    @division_a = @tournament.divisions.create!(letter_level: 'A', active: true)
    @division_b = @tournament.divisions.create!(letter_level: 'B', active: true)
  end

  def create_numbered_tournament
    Tournament.create!(
      name: 'Numbered Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'numbered',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-16 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :draft
    )
  end

  # --- create -----------------------------------------------------------------

  test 'creates a letter division' do
    division = TournamentDivisionService.create(@tournament, letter_level: 'AA', active: true)

    assert division.persisted?
    assert_equal 'AA', division.letter_level
    assert_equal 'AA', division.division_code
  end

  test 'rejects a letter level on a numbered tournament' do
    numbered = create_numbered_tournament

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentDivisionService.create(numbered, letter_level: 'A', active: true)
    end

    assert_match(/letter scheme/, error.message)
    assert_not numbered.divisions.exists?(letter_level: 'A')
  end

  test 'rejects a division number on a letter tournament' do
    assert_raises ActiveRecord::RecordInvalid do
      TournamentDivisionService.create(@tournament, division_number: 1, active: true)
    end
  end

  test 'rejects a duplicate division code' do
    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentDivisionService.create(@tournament, letter_level: 'A', active: true)
    end

    assert_match(/already been taken/, error.message)
  end

  # --- update -----------------------------------------------------------------

  test 'deactivates a division while another active one remains' do
    updated = TournamentDivisionService.update(@division_b, active: false)

    assert_not updated.active
    assert @division_a.reload.active
  end

  test 'refuses to deactivate the final active division' do
    @division_b.update!(active: false)

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentDivisionService.update(@division_a, active: false)
    end

    assert_match(/final active division/, error.message)
    assert @division_a.reload.active
  end

  test 'locks the code of a referenced division' do
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentDivisionService.update(@division_a, letter_level: 'AAA')
    end

    assert_match(/retire it instead/, error.message)
    assert_equal 'A', @division_a.reload.letter_level
  end

  test 'allows renaming an unreferenced division' do
    updated = TournamentDivisionService.update(@division_a, letter_level: 'AAA')

    assert_equal 'AAA', updated.letter_level
  end

  # --- destroy ----------------------------------------------------------------

  test 'deletes an unreferenced division when it is not the final active one' do
    result = TournamentDivisionService.destroy(@division_b)

    assert_equal false, result[:retired]
    assert_not @tournament.divisions.exists?(@division_b.id)
  end

  test 'refuses to remove the final active division' do
    @division_b.update!(active: false)

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentDivisionService.destroy(@division_a)
    end

    assert_match(/final active division/, error.message)
    assert @tournament.divisions.exists?(@division_a.id)
  end

  test 'retires instead of deleting a referenced division' do
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )

    result = TournamentDivisionService.destroy(@division_a)

    assert_equal true, result[:retired]
    assert @tournament.divisions.exists?(@division_a.id)
    assert_not @division_a.reload.active
  end

  test 'deletes an inactive unreferenced division outright' do
    @division_b.update!(active: false)

    result = TournamentDivisionService.destroy(@division_b)

    assert_equal false, result[:retired]
    assert_not @tournament.divisions.exists?(@division_b.id)
  end
end
