require 'test_helper'

class TournamentParticipationDivisionTest < ActiveSupport::TestCase
  def setup
    @organisation = Organisation.create!(name: 'Test Org', slug: 'test-org')
    @account = Account.create!(user: User.create!(email: 'test@example.com', password: 'password'))
    @tournament = Tournament.create!(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
  end

  test 'should be valid with valid attributes' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    division = @tournament.divisions.create!(letter_level: 'A')
    tpd = TournamentParticipationDivision.new(
      tournament_participation: participation,
      tournament_division: division,
      tournament: @tournament
    )
    assert tpd.valid?
  end

  test 'should require tournament participation' do
    division = @tournament.divisions.create!(letter_level: 'A')
    tpd = TournamentParticipationDivision.new(
      tournament_division: division,
      tournament: @tournament
    )
    assert_not tpd.valid?
    assert_includes tpd.errors[:tournament_participation], "must exist"
  end

  test 'should require tournament division' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    tpd = TournamentParticipationDivision.new(
      tournament_participation: participation,
      tournament: @tournament
    )
    assert_not tpd.valid?
    assert_includes tpd.errors[:tournament_division], "must exist"
  end

  test 'should require tournament' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    division = @tournament.divisions.create!(letter_level: 'A')
    tpd = TournamentParticipationDivision.new(
      tournament_participation: participation,
      tournament_division: division
    )
    assert_not tpd.valid?
    assert_includes tpd.errors[:tournament], "must exist"
  end

  test 'should validate uniqueness of tournament participation scoped to tournament division' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    division = @tournament.divisions.create!(letter_level: 'A')
    TournamentParticipationDivision.create!(
      tournament_participation: participation,
      tournament_division: division,
      tournament: @tournament
    )
    tpd = TournamentParticipationDivision.new(
      tournament_participation: participation,
      tournament_division: division,
      tournament: @tournament
    )
    assert_not tpd.valid?
    assert_includes tpd.errors[:tournament_participation_id], "has already been taken"
  end

  test 'should belong to tournament participation, tournament division, and tournament' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    division = @tournament.divisions.create!(letter_level: 'A')
    tpd = TournamentParticipationDivision.create!(
      tournament_participation: participation,
      tournament_division: division,
      tournament: @tournament
    )
    assert_equal participation, tpd.tournament_participation
    assert_equal division, tpd.tournament_division
    assert_equal @tournament, tpd.tournament
  end

  test 'should validate tournament consistency' do
    # Create another tournament
    other_organisation = Organisation.create!(name: 'Other Org', slug: 'other-org')
    other_tournament = Tournament.create!(
      name: 'Other Tournament',
      organisation: other_organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )

    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    division = @tournament.divisions.create!(letter_level: 'A')

    # Try to create a TPD with mismatched tournament
    tpd = TournamentParticipationDivision.new(
      tournament_participation: participation,
      tournament_division: division,
      tournament: other_tournament
    )
    assert_not tpd.valid?
    assert_includes tpd.errors[:base], "Tournament mismatch between participation, division, and record"
  end
end