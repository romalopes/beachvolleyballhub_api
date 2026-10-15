require 'test_helper'

class TournamentParticipationServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: 'Test Org', acronym: 'TO')
    @account = create_account!
    @tournament = Tournament.create!(
      name: 'Tournament for Participation',
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
    @division_a = @tournament.divisions.create!(letter_level: 'A', active: true)
    @division_b = @tournament.divisions.create!(letter_level: 'B', active: true)
  end

  test 'should link and update participation' do
    # Link
    participation = TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )
    assert participation.persisted?
    assert_equal 'player', participation.role
    assert_equal 1, participation.participation_divisions.count

    # Update — a coach may switch divisions, unlike a referee
    participation = TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'coach', division_ids: [@division_b.id]
    )
    assert_equal 'coach', participation.role
    assert_equal 1, participation.participation_divisions.count
    assert_equal @division_b.id, participation.participation_divisions.first.tournament_division_id
  end

  test 'should be idempotent for link' do
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )
    assert_no_difference 'TournamentParticipation.count' do
      TournamentParticipationService.link_or_update_participation(
        @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
      )
    end
  end

  test 'should unlink participation' do
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )
    assert_difference 'TournamentParticipation.count', -1 do
      TournamentParticipationService.unlink_participation(@account.id, @tournament.id)
    end
  end

  test 'should allow unlinking even if tournament is archived' do
    # Link while the tournament is still active, then archive — unlinking must
    # remain possible afterwards (linking itself is rejected once archived).
    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )
    @tournament.update!(publication_state: :archived)
    assert_difference 'TournamentParticipation.count', -1 do
      TournamentParticipationService.unlink_participation(@account.id, @tournament.id)
    end
  end

  test 'should raise error when linking to non-active tournament' do
    @tournament.update!(publication_state: :cancelled)
    assert_raises ActiveRecord::RecordInvalid do
      TournamentParticipationService.link_or_update_participation(
        @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
      )
    end
  end

  test 'should not allow linking to division from another tournament' do
    other_tournament = Tournament.create!(
      name: 'Other Tournament',
      organisation_id: @organisation.id,
      created_by_account_id: @account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-16 09:00:00',
      ends_at: '2026-10-16 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :active
    )
    other_division = other_tournament.divisions.create!(letter_level: 'A', active: true)
    assert_raises ActiveRecord::RecordInvalid do
      TournamentParticipationService.link_or_update_participation(
        @account.id, @tournament.id, role: 'player', division_ids: [other_division.id]
      )
    end
  end

  test 'allows retaining but not newly adding an inactive division' do
    participation = TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id]
    )
    @division_a.update!(active: false)

    TournamentParticipationService.link_or_update_participation(
      @account.id, @tournament.id, role: 'coach', division_ids: [@division_a.id]
    )
    assert_equal [@division_a.id], participation.reload.participation_divisions.pluck(:tournament_division_id)

    inactive_division = @tournament.divisions.create!(letter_level: 'AA', active: false)
    assert_raises ActiveRecord::RecordInvalid do
      TournamentParticipationService.link_or_update_participation(
        @account.id, @tournament.id, role: 'player', division_ids: [@division_a.id, inactive_division.id]
      )
    end
  end

  test 'does not allow a referee or organiser to select divisions' do
    assert_raises ActiveRecord::RecordInvalid do
      TournamentParticipationService.link_or_update_participation(
        @account.id, @tournament.id, role: 'referee', division_ids: [@division_a.id]
      )
    end
  end
end