require 'test_helper'

class TournamentDivisionTest < ActiveSupport::TestCase
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

  test 'should be valid with letter level' do
    division = TournamentDivision.new(
      tournament: @tournament,
      letter_level: 'A'
    )
    assert division.valid?
  end

  test 'should be valid with division number' do
    numbered_tournament = Tournament.create!(
      name: 'Numbered Tournament',
      organisation: @organisation,
      scope: 'club',
      division_scheme: 'numbered',
      starts_at: DateTime.now,
      ends_at: DateTime.now + 1.day,
      timezone: 'UTC',
      created_by_account: @account
    )
    division = TournamentDivision.new(
      tournament: numbered_tournament,
      division_number: 1
    )
    assert division.valid?
  end

  test 'should not be valid with both letter level and division number' do
    division = TournamentDivision.new(
      tournament: @tournament,
      letter_level: 'A',
      division_number: 1
    )
    assert_not division.valid?
    assert_includes division.errors[:base], "Specify either letter level or division number, not both"
  end

  test 'should not be valid without letter level or division number' do
    division = TournamentDivision.new(
      tournament: @tournament
    )
    assert_not division.valid?
    assert_includes division.errors[:base], "Specify either letter level or division number"
  end

  test 'should require tournament' do
    division = TournamentDivision.new(
      letter_level: 'A'
    )
    assert_not division.valid?
    assert_includes division.errors[:tournament], "must exist"
  end

  test 'should validate letter level inclusion' do
    division = TournamentDivision.new(
      tournament: @tournament,
      letter_level: 'INVALID'
    )
    assert_not division.valid?
    assert_includes division.errors[:letter_level], "is not included in the list"
  end

  test 'should validate division number numericality' do
    division = TournamentDivision.new(
      tournament: @tournament,
      division_number: -1
    )
    assert_not division.valid?
    assert_includes division.errors[:division_number], "must be greater than 0"
  end

  test 'should belong to tournament' do
    division = @tournament.divisions.create!(letter_level: 'A')
    assert_equal @tournament, division.tournament
  end

  test 'should compute strength order for letter levels' do
    division = TournamentDivision.new(tournament: @tournament, letter_level: 'AAAA')
    assert_equal 1, division.strength_order
    division.letter_level = 'AAA'
    assert_equal 2, division.strength_order
    division.letter_level = 'AA'
    assert_equal 3, division.strength_order
    division.letter_level = 'A'
    assert_equal 4, division.strength_order
    division.letter_level = 'BBB'
    assert_equal 5, division.strength_order
    division.letter_level = 'BB'
    assert_equal 6, division.strength_order
    division.letter_level = 'B'
    assert_equal 7, division.strength_order
  end

  test 'should compute strength order for division numbers' do
    division = TournamentDivision.new(tournament: @tournament, division_number: 5)
    assert_equal 5, division.strength_order
  end

  test 'should return division code' do
    division = TournamentDivision.new(tournament: @tournament, letter_level: 'A')
    assert_equal 'A', division.division_code
    division = TournamentDivision.new(tournament: @tournament, division_number: 3)
    assert_equal '3', division.division_code
  end
end