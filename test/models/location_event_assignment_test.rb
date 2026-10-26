require "test_helper"

class LocationEventAssignmentTest < ActiveSupport::TestCase
  setup do
    @proposer = accounts(:one)
    @other_account = accounts(:two)
    @proposal = Location.create!(name: "Pending Beach", proposed_by_account: @proposer)
  end

  test "tournament ignores retired location columns" do
    assert_empty Tournament.column_names & %w[city state country]
  end

  test "tournament accepts its creator's proposal and rejects another account's proposal" do
    tournament = Tournament.new(
      organisation: organisations(:sydney_club),
      created_by_account: @proposer,
      name: "Proposal Cup",
      scope: "club",
      division_scheme: "letter",
      starts_at: 1.day.from_now,
      ends_at: 2.days.from_now,
      timezone: "UTC",
      publication_state: "draft",
      location: @proposal
    )
    assert tournament.valid?, tournament.errors.full_messages.to_sentence

    tournament.created_by_account = @other_account
    assert_not tournament.valid?
    assert_includes tournament.errors[:location], "must be verified or your own active proposal"
  end

  test "training accepts its creator's proposal and rejects another user's proposal" do
    training = TrainingSession.new(
      title: "Proposal Training",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 2.hours,
      status: "scheduled",
      visibility: "shared",
      created_by: @proposer.user,
      canonical_location: @proposal
    )
    assert training.valid?, training.errors.full_messages.to_sentence

    training.created_by = @other_account.user
    assert_not training.valid?
    assert_includes training.errors[:location], "must be verified or your own active proposal"
  end
end
