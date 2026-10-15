require 'test_helper'

class TournamentWatchLinkTest < ActiveSupport::TestCase
  def setup
    @organisation = Organisation.create!(name: 'Test Org', slug: 'test-org')
    @account = Account.create!(user: User.create!(email_address: 'test@example.com', password: 'password'))
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
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      name: 'YouTube',
      url: 'https://youtube.com/live',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: 0
    )
    assert watch_link.valid?
  end

  test 'should require tournament' do
    watch_link = TournamentWatchLink.new(
      name: 'YouTube',
      url: 'https://youtube.com/live',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: 0
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:tournament], "must exist"
  end

  test 'should require name' do
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      url: 'https://youtube.com/live',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: 0
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:name], "can't be blank"
  end

  test 'should require url' do
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      name: 'YouTube',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: 0
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:url], "can't be blank"
  end

  test 'should validate url format' do
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      name: 'YouTube',
      url: 'not-a-url',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: 0
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:url], "is invalid"
  end

  test 'should require provider' do
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      name: 'YouTube',
      url: 'https://youtube.com/live',
      starts_at: DateTime.now,
      position: 0
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:provider], "can't be blank"
  end

  test 'should require starts_at' do
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      name: 'YouTube',
      url: 'https://youtube.com/live',
      provider: 'youtube',
      position: 0
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:starts_at], "can't be blank"
  end

  test 'should validate position numericality' do
    watch_link = TournamentWatchLink.new(
      tournament: @tournament,
      name: 'YouTube',
      url: 'https://youtube.com/live',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: -1
    )
    assert_not watch_link.valid?
    assert_includes watch_link.errors[:position], "must be greater than or equal to 0"
  end

  test 'should belong to tournament' do
    watch_link = @tournament.watch_links.create!(
      name: 'YouTube',
      url: 'https://youtube.com/live',
      provider: 'youtube',
      starts_at: DateTime.now,
      position: 0
    )
    assert_equal @tournament, watch_link.tournament
  end
end