require 'test_helper'

class TournamentTest < ActiveSupport::TestCase
  def setup
    @organisation = Organisation.create!(name: 'Test Org', slug: 'test-org')
    @account = Account.create!(user: User.create!(email: 'test@example.com', password: 'password'))
  end

  test 'should be valid with valid attributes' do
    tournament = Tournament.new(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    assert tournament.valid?
  end

  test 'should require name' do
    tournament = Tournament.new(
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    assert_not tournament.valid?
    assert_includes tournament.errors[:name], "can't be blank"
  end

  test 'should require scope' do
    tournament = Tournament.new(
      name: 'Test Tournament',
      organisation: @organisation,
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    assert_not tournament.valid?
    assert_includes tournament.errors[:scope], "can't be blank"
  end

  test 'should have valid scope' do
    tournament = Tournament.new(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'invalid',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    assert_not tournament.valid?
    assert_includes tournament.errors[:scope], "is not included in the list"
  end

  test 'ends_at must be after starts_at' do
    tournament = Tournament.new(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now + 1.day,
      ends_at: DateTime.now,
      timezone: 'UTC',
      created_by_account: @account
    )
    assert_not tournament.valid?
    assert_includes tournament.errors[:ends_at], "must be after the start date"
  end

  test 'should belong to organisation and account' do
    tournament = Tournament.create!(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    assert_equal @organisation, tournament.organisation
    assert_equal @account, tournament.created_by_account
  end

  test 'should have many divisions' do
    tournament = Tournament.create!(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    division = tournament.divisions.create!(letter_level: 'A')
    assert_includes tournament.divisions, division
  end

  test 'should have many participations' do
    tournament = Tournament.create!(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    participation = tournament.participations.create!(account: @account, role: 'player')
    assert_includes tournament.participations, participation
  end

  test 'should have many watch links' do
    tournament = Tournament.create!(
      name: 'Test Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    watch_link = tournament.watch_links.create!(name: 'YouTube', url: 'https://youtube.com', provider: 'youtube', starts_at: DateTime.now)
    assert_includes tournament.watch_links, watch_link
  end
end