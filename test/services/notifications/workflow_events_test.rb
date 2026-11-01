require "test_helper"

# Domain event rules: who is told what for a training transition and for a
# membership request/decision. These tests own the "recipient correctness" half
# of the plan's privacy requirement.
class Notifications::WorkflowEventsTest < ActiveSupport::TestCase
  setup do
    @coach = accounts(:two)     # owns the Sydney club, coaches the sessions
    @player = accounts(:one)    # participant of training_sessions(:one)
    @training = training_sessions(:one)
  end

  # --- training ---------------------------------------------------------------

  test "a reschedule notifies the participants and nobody else" do
    previous = { "status" => "scheduled", "starts_at" => @training.starts_at,
                 "ends_at" => @training.ends_at, "participant_account_ids" => [ @player.id ] }

    @training.update!(starts_at: @training.starts_at + 1.hour)

    assert_difference("Notification.where(event_type: 'training.rescheduled').count", 1) do
      Notifications::WorkflowEvents.training_changed(@training, actor: @coach, previous: previous)
    end

    notification = Notification.find_by(event_type: "training.rescheduled")
    assert_equal @player.id, notification.account_id
    assert_equal "/training/#{@training.id}", notification.target_path
  end

  test "a cancellation notifies participants" do
    previous = { "status" => "scheduled", "starts_at" => @training.starts_at,
                 "ends_at" => @training.ends_at, "participant_account_ids" => [ @player.id ] }
    @training.mark_cancelled!(reason: "Weather", actor: @coach.user)

    assert_difference("Notification.where(event_type: 'training.cancelled').count", 1) do
      Notifications::WorkflowEvents.training_changed(@training.reload, actor: @coach, previous: previous)
    end
  end

  test "adding a participant notifies only the newly added account" do
    new_profile = accounts(:three).player_profiles.create!(
      display_name: "Late Joiner", status: "active", visibility: "shared"
    )
    previous = { "status" => "scheduled", "starts_at" => @training.starts_at,
                 "ends_at" => @training.ends_at, "participant_account_ids" => [ @player.id ] }
    @training.training_session_participants.create!(player_profile: new_profile, status: "invited")

    assert_difference("Notification.where(event_type: 'training.invited').count", 1) do
      Notifications::WorkflowEvents.training_changed(@training.reload, actor: @coach, previous: previous)
    end

    assert_equal accounts(:three).id, Notification.find_by(event_type: "training.invited").account_id
  end

  test "a training with no account-bearing participants notifies nobody" do
    session = training_sessions(:three) # curator session with no participants
    previous = { "status" => "scheduled", "starts_at" => session.starts_at,
                 "ends_at" => session.ends_at, "participant_account_ids" => [] }

    assert_no_difference("Notification.count") do
      Notifications::WorkflowEvents.training_changed(session, actor: @coach, previous: previous)
    end
  end

  test "an unchanged training emits nothing" do
    previous = { "status" => "scheduled", "starts_at" => @training.starts_at,
                 "ends_at" => @training.ends_at, "participant_account_ids" => [ @player.id ] }

    assert_no_difference("Notification.count") do
      Notifications::WorkflowEvents.training_changed(@training, actor: @coach, previous: previous)
    end
  end

  # --- membership -------------------------------------------------------------

  test "a pending join request notifies the organisation approvers" do
    organisation = organisations(:sydney_club)
    membership = organisation.organisation_memberships.create!(
      account: accounts(:three), memberable: accounts(:three), role: "member", status: "pending"
    )

    assert_difference("Notification.where(event_type: 'membership.requested').count", 1) do
      Notifications::WorkflowEvents.membership_requested(organisation, membership, actor: accounts(:three))
    end

    notification = Notification.find_by(event_type: "membership.requested")
    # accounts(:two) owns the club; the requester is not told about their own ask.
    assert_equal @coach.id, notification.account_id
  end

  test "an approval notifies only the requester" do
    organisation = organisations(:sydney_club)
    membership = organisation.organisation_memberships.create!(
      account: accounts(:three), memberable: accounts(:three), role: "member", status: "pending"
    )

    assert_difference("Notification.where(event_type: 'membership.approved').count", 1) do
      Notifications::WorkflowEvents.membership_decided(
        organisation, membership, actor: @coach, decision: "approved"
      )
    end

    assert_equal accounts(:three).id, Notification.find_by(event_type: "membership.approved").account_id
  end

  test "a group approval notifies the requester with a group target path" do
    group = groups(:u19_squad)
    membership = group.group_memberships.create!(
      account: accounts(:three), memberable: accounts(:three), role: "member", status: "pending"
    )

    Notifications::WorkflowEvents.membership_decided(group, membership, actor: @coach, decision: "approved")

    notification = Notification.find_by(event_type: "membership.approved")
    assert_equal accounts(:three).id, notification.account_id
    assert_equal "/groups/#{group.id}", notification.target_path
  end
end
