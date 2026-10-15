require 'test_helper'

class TournamentParticipationTest < ActiveSupport::TestCase
  def setup
    @organisation = Organisation.create!(name: 'Test Org', slug: 'test-org')
    @account = Account.create!(user: User.create!(email_address: 'test@example.com', password: 'password'))
    @other_account = Account.create!(user: User.create!(email_address: 'other@example.com', password: 'password'))
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
    participation = TournamentParticipation.new(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    assert participation.valid?
  end

  test 'should require account' do
    participation = TournamentParticipation.new(
      tournament: @tournament,
      role: 'player'
    )
    assert_not participation.valid?
    assert_includes participation.errors[:account], "must exist"
  end

  test 'should require tournament' do
    participation = TournamentParticipation.new(
      account: @account,
      role: 'player'
    )
    assert_not participation.valid?
    assert_includes participation.errors[:tournament], "must exist"
  end

  test 'should require role' do
    participation = TournamentParticipation.new(
      account: @account,
      tournament: @tournament
    )
    assert_not participation.valid?
    assert_includes participation.errors[:role], "can't be blank"
  end

  test 'rejects an invalid role' do
    assert_raises ArgumentError do
      TournamentParticipation.new(
        account: @account,
        tournament: @tournament,
        role: 'invalid'
      )
    end
  end

  test 'should validate uniqueness of account scoped to tournament' do
    TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    participation = TournamentParticipation.new(
      account: @account,
      tournament: @tournament,
      role: 'coach'
    )
    assert_not participation.valid?
    assert_includes participation.errors[:account_id], "has already been taken"
  end

  test 'should allow same account in different tournaments' do
    other_tournament = Tournament.create!(
      name: 'Other Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    participation1 = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    participation2 = TournamentParticipation.create!(
      account: @account,
      tournament: other_tournament,
      role: 'player'
    )
    assert participation1.valid?
    assert participation2.valid?
  end

  test 'should belong to account and tournament' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    assert_equal @account, participation.account
    assert_equal @tournament, participation.tournament
  end

  test 'should have many participation divisions' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'player'
    )
    division = @tournament.divisions.create!(letter_level: 'A')
    participation_division = participation.participation_divisions.create!(
      tournament_division: division,
      tournament: @tournament
    )
    assert_includes participation.participation_divisions, participation_division
  end

  test 'organisers scope' do
    participation = TournamentParticipation.create!(
      account: @account,
      tournament: @tournament,
      role: 'organiser'
    )
    assert_includes TournamentParticipation.organisers, participation
  end
end