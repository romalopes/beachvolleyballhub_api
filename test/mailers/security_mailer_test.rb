require "test_helper"

class SecurityMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      email_address: "security-mailer@example.com",
      password: "password123",
      email_verified_at: Time.current
    )
    Account.create!(
      user: @user,
      contact_detail: ContactDetail.new(
        first_name: "Security",
        last_name: "Mailer",
        email: "security-mailer@example.com"
      )
    )
    @details_hash = LoginDetails.new(
      email: "security-mailer@example.com",
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
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "renders a multipart email with the login details" do
    email = SecurityMailer.new_login_email(@user, @details_hash).deliver_now

    assert_equal [@user.email_address], email.to
    assert_includes email.subject, "New sign-in"

    assert email.multipart?
    refute_empty email.text_part&.body.to_s
    refute_empty email.html_part&.body.to_s

    body = email.text_part.body.to_s + email.html_part.body.to_s
    assert_includes body, "203.0.113.10"
    assert_includes body, "Chrome"
    assert_includes body, "macOS"
    assert_includes body, "Desktop"
    assert_includes body, "password"
    assert_includes body, "/reset-password"
  end

  test "renders Unknown alone, never Unknown Unknown, when version is Unknown" do
    # Build a details object whose browser_version is Unknown.
    details = LoginDetails.new(
      email: @user.email_address,
      login_at: Time.current,
      ip_address: "203.0.113.10",
      user_agent: "",
      browser: "Unknown",
      browser_version: LoginDetails::UNKNOWN,
      os: LoginDetails::UNKNOWN,
      device: LoginDetails::UNKNOWN,
      location: LoginDetails::UNKNOWN,
      login_method: "password",
      mobile: false
    )

    email = SecurityMailer.new_login_email(@user, details.serializable_hash).deliver_now
    body = email.text_part.body.to_s + email.html_part.body.to_s

    assert_includes body, "Browser:          Unknown"
    refute_includes body, "Unknown Unknown"
  end
end
