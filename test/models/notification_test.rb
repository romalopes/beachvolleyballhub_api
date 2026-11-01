require "test_helper"

# Model rules for a notification row: the fields that make it renderable, the
# per-account idempotency key, and the read lifecycle.
class NotificationTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @notification = @account.notifications.create!(
      event_type: "training.cancelled",
      event_key: "training:1:cancelled-1",
      title: "Training cancelled",
      message: "Serve Reception Training has been cancelled."
    )
  end

  test "requires the fields the bell and inbox render from" do
    notification = Notification.new(account: @account)

    assert_not notification.valid?
    assert_equal %i[event_type event_key title message].sort,
                 notification.errors.attribute_names.sort
  end

  test "event_key is unique per account but reusable across accounts" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      @account.notifications.create!(
        event_type: "training.cancelled",
        event_key: @notification.event_key,
        title: "Duplicate",
        message: "Duplicate"
      )
    end

    other = accounts(:two).notifications.create!(
      event_type: "training.cancelled",
      event_key: @notification.event_key,
      title: "Same key, different recipient",
      message: "Same key, different recipient"
    )
    assert other.persisted?
  end

  test "starts unread and records read state idempotently" do
    assert_not @notification.read?
    assert_nil @notification.read_at

    @notification.mark_read!
    first_read_at = @notification.reload.read_at
    assert @notification.read?

    @notification.mark_read!
    assert_equal first_read_at, @notification.reload.read_at
  end

  test "unread and by_recency scopes drive the inbox query" do
    older = @account.notifications.create!(
      event_type: "training.invited",
      event_key: "training:1:participants-1",
      title: "Older",
      message: "Older",
      created_at: 2.days.ago
    )
    @notification.mark_read!

    assert_equal [ older.id ], @account.notifications.unread.pluck(:id)
    assert_equal [ @notification.id, older.id ],
                 @account.notifications.by_recency.pluck(:id)
  end

  test "actor_account is optional and deletion nullifies it" do
    system_notification = @account.notifications.create!(
      event_type: "system.announcement",
      event_key: "system:1",
      title: "No actor",
      message: "No actor"
    )
    assert_nil system_notification.actor_account

    # A dedicated account so it can actually be destroyed: the fixture accounts
    # carry profiles/memberships whose `restrict_with_error` blocks deletion.
    actor = create_account!(first_name: "Event", last_name: "Actor")
    @notification.update!(actor_account: actor)

    actor.destroy
    assert_nil @notification.reload.actor_account_id
  end

  test "destroying the account removes its notifications" do
    account = create_account!(first_name: "Notify", last_name: "Recipient")
    account.notifications.create!(
      event_type: "training.cancelled",
      event_key: "training:9:cancelled-1",
      title: "Cancelled",
      message: "Cancelled"
    )

    assert_difference("Notification.where(account_id: #{account.id}).count", -1) do
      account.destroy
    end
  end
end
