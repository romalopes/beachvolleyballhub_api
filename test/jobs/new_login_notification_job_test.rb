require "test_helper"

class NewLoginNotificationJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "login-notify@example.com",
      password: "password123",
      email_verified_at: Time.current
    )
    Account.create!(
      user: @user,
      contact_detail: ContactDetail.new(
        first_name: "Login",
        last_name: "Notify",
        email: "login-notify@example.com"
      )
    )
    @details_hash = LoginDetails.new(
      email: "login-notify@example.com",
      login_at: Time.current,
      ip_address: "203.0.113.10",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/605.1.15",
      browser: "Chrome",
      browser_version: "131.0.0.0",
      os: "macOS 10.15.7",
      device: "Desktop",
      location: "Unknown",
      login_method: "password",
      mobile: false
    ).serializable_hash

    # Use the test queue adapter to prove this job does not enqueue a second
    # ActionMailer::MailDeliveryJob.
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  test "delivers the new login email to the user" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      NewLoginNotificationJob.perform_now(@user.id, @details_hash)
    end

    assert_empty ActiveJob::Base.queue_adapter.enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email_address ], mail.to
    assert_includes mail.subject, "New sign-in"
  end

  test "email body contains ip, browser, os, device and sign-in method" do
    NewLoginNotificationJob.perform_now(@user.id, @details_hash)

    mail = ActionMailer::Base.deliveries.last
    body = mail.text_part&.body.to_s + mail.html_part&.body.to_s

    assert_includes body, "203.0.113.10"
    assert_includes body, "Chrome"
    assert_includes body, "macOS"
    assert_includes body, "Desktop"
    assert_includes body, "password"
  end

  test "does nothing when the user is missing" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      NewLoginNotificationJob.perform_now(-1, @details_hash)
    end
  end

  test "passes a plain-JSON-serialisable hash through ActiveJob arguments" do
    assert_nothing_raised do
      ActiveJob::Arguments.serialize([ @user.id, @details_hash ])
    end
  end

  test "does not deliver when details_hash is blank" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      NewLoginNotificationJob.perform_now(@user.id, {})
    end
  end
end
