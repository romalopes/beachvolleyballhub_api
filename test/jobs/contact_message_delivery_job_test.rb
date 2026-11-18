require "test_helper"

# Delivery job for public contact enquiries (IDENTITY-259).
#
# Pinned here: the email reaches every configured recipient, only platform
# Admins/Curators are notified in-app, a retry never duplicates either, and a
# delivery failure never deletes the stored message.
class ContactMessageDeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @message = contact_messages(:unread_general)
    @previous_recipients = ENV["CONTACT_NOTIFICATION_EMAILS"]
    @previous_frontend = ENV["FRONTEND_URL"]
    ENV["CONTACT_NOTIFICATION_EMAILS"] = "support@beachvolleyballhub.com"
    ENV["FRONTEND_URL"] = "https://beachvolleyballhub.com"
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    restore_env("CONTACT_NOTIFICATION_EMAILS", @previous_recipients)
    restore_env("FRONTEND_URL", @previous_frontend)
    @message.update_columns(emailed_at: nil, notified_at: nil)
  end

  def contact_notifications
    Notification.where(event_type: "contact.message.received")
  end

  test "emails the configured recipients and marks the message delivered" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      ContactMessageDeliveryJob.perform_now(@message.id)
    end

    assert_equal [ "support@beachvolleyballhub.com" ], ActionMailer::Base.deliveries.last.to
    assert_not_nil @message.reload.emailed_at
  end

  test "notifies platform admins and curators but not coaches, players or ordinary accounts" do
    curator_account = Account.create!(
      user: users(:four),
      contact_detail: ContactDetail.new(first_name: "Casey", last_name: "Curator", email: "curator@example.com")
    )

    ContactMessageDeliveryJob.perform_now(@message.id)

    notified = contact_notifications.pluck(:account_id)

    assert_includes notified, accounts(:admin).id, "expected the platform admin to be notified"
    assert_includes notified, curator_account.id, "expected the platform curator to be notified"
    assert_not_includes notified, accounts(:three).id, "a coach must not be notified"
    assert_not_includes notified, accounts(:one).id, "an ordinary account must not be notified"
    assert_not_nil @message.reload.notified_at
  end

  test "the notification links to the inbox detail route" do
    ContactMessageDeliveryJob.perform_now(@message.id)

    notification = contact_notifications.first

    assert_equal "New contact message", notification.title
    assert_equal "/settings/contact-messages/#{@message.id}", notification.target_path
    assert_equal @message.subject, notification.target_label
    assert_includes notification.message, "Jordan Smith"
  end

  test "a second run does not send or notify twice" do
    ContactMessageDeliveryJob.perform_now(@message.id)
    first_deliveries = ActionMailer::Base.deliveries.size
    first_notifications = contact_notifications.count

    ContactMessageDeliveryJob.perform_now(@message.id)

    assert_equal first_deliveries, ActionMailer::Base.deliveries.size
    assert_equal first_notifications, contact_notifications.count
  end

  test "an unconfigured recipient list leaves the message stored and readable" do
    ENV["CONTACT_NOTIFICATION_EMAILS"] = ""

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      ContactMessageDeliveryJob.perform_now(@message.id)
    end

    assert ContactMessage.exists?(@message.id)
    assert_nil @message.reload.emailed_at
  end

  test "a delivery failure keeps the message and re-raises for the retry policy" do
    # `perform_now` would swallow this via retry_on (it enqueues a retry), so the
    # job's own contract is asserted through `perform`: the error must escape so
    # the framework can retry and monitoring can see it.
    assert_raises(IOError) do
      with_failing_delivery { ContactMessageDeliveryJob.new.perform(@message.id) }
    end

    assert ContactMessage.exists?(@message.id)
    assert_nil @message.reload.emailed_at
  end

  test "a delivery failure is retried by the job's retry policy" do
    clear_enqueued_jobs

    with_failing_delivery { ContactMessageDeliveryJob.perform_now(@message.id) }

    assert_enqueued_with(job: ContactMessageDeliveryJob, args: [ @message.id ])
  ensure
    clear_enqueued_jobs
  end

  test "an unknown message id is a no-op" do
    assert_nothing_raised do
      ContactMessageDeliveryJob.perform_now(0)
    end
  end

  private

  # Overrides the mailer's class-level entry point for the duration of the
  # block, so the job sees a provider failure without any network access.
  def with_failing_delivery
    ContactMessageMailer.define_singleton_method(:notification) do |*, **|
      raise IOError, "provider down"
    end
    yield
  ensure
    ContactMessageMailer.singleton_class.remove_method(:notification)
  end

  def restore_env(key, value)
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end
