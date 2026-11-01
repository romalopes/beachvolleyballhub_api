require "test_helper"

# The publisher is the one place notifications are created, so its contract is
# pinned here: recipient filtering, idempotency, and the "created" flag the later
# email channel relies on.
class Notifications::PublisherTest < ActiveSupport::TestCase
  setup do
    @recipient = accounts(:one)
    @other = accounts(:two)
  end

  def publish(recipients:, event_key: "training:1:cancelled-1")
    Notifications::Publisher.publish(
      recipients: recipients,
      event_type: "training.cancelled",
      event_key: event_key,
      title: "Training cancelled",
      message: "A training was cancelled.",
      actor: @other,
      target_path: "/training/1",
      target_label: "Serve Reception Training"
    )
  end

  test "creates one notification per recipient and reports it as created" do
    results = publish(recipients: [ @recipient, @other ])

    assert_equal 2, results.size
    assert results.all?(&:created)
    assert_equal [ @recipient.id, @other.id ].sort,
                 Notification.where(event_key: "training:1:cancelled-1").pluck(:account_id).sort
  end

  test "replaying the same event key is idempotent" do
    publish(recipients: [ @recipient ])

    assert_no_difference("Notification.count") do
      results = publish(recipients: [ @recipient ])
      assert_equal 1, results.size
      assert_not results.first.created, "the existing row must not report as newly created"
    end
  end

  test "deduplicates repeated recipients in one call" do
    assert_difference("Notification.count", 1) do
      publish(recipients: [ @recipient, @recipient ])
    end
  end

  test "writes nothing for an account that muted the event type" do
    @recipient.create_notification_preference!(muted_event_types: [ "training.cancelled" ])

    assert_no_difference("Notification.count") do
      assert_empty publish(recipients: [ @recipient ])
    end
  end

  test "writes nothing when the account disabled in-app notifications" do
    @recipient.create_notification_preference!(in_app_enabled: false)

    assert_no_difference("Notification.count") do
      assert_empty publish(recipients: [ @recipient ])
    end
  end

  test "carries the actor, target and metadata onto the row" do
    notification = publish(recipients: [ @recipient ]).first.notification

    assert_equal @other.id, notification.actor_account_id
    assert_equal "/training/1", notification.target_path
    assert_equal "Serve Reception Training", notification.target_label
  end

  test "ignores nil recipients" do
    assert_no_difference("Notification.count") do
      assert_empty publish(recipients: [ nil ])
    end
  end
end
