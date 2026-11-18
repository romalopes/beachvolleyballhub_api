require "test_helper"

# The notification email for a public enquiry (IDENTITY-259).
#
# Pinned here: every configured recipient gets the message, the visitor is only a
# Reply-To (never From), the content staff need is present, and user-controlled
# values are escaped in the HTML part.
class ContactMessageMailerTest < ActionMailer::TestCase
  setup do
    @message = contact_messages(:unread_general)
    @previous_recipients = ENV["CONTACT_NOTIFICATION_EMAILS"]
    @previous_frontend = ENV["FRONTEND_URL"]
    ENV["CONTACT_NOTIFICATION_EMAILS"] = "support@beachvolleyballhub.com, admin@beachvolleyballhub.com"
    ENV["FRONTEND_URL"] = "https://beachvolleyballhub.com"
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    restore_env("CONTACT_NOTIFICATION_EMAILS", @previous_recipients)
    restore_env("FRONTEND_URL", @previous_frontend)
  end

  def deliver(message = @message)
    ContactMessageMailer
      .notification(message, inbox_url: "https://beachvolleyballhub.com/settings/contact-messages/#{message.id}")
      .deliver_now
  end

  test "is delivered to every configured recipient" do
    email = deliver

    assert_equal [ "support@beachvolleyballhub.com", "admin@beachvolleyballhub.com" ], email.to
  end

  test "uses the application sender and replies to the visitor" do
    email = deliver

    # Built by the mail gem: the display name lives in the header field.
    assert_equal MailSender.from, email[:from].to_s
    assert_equal [ "jordan@example.com" ], email.reply_to
    # The visitor's address must never become the envelope From (SPF/DMARC and
    # spoofing risk).
    refute_includes email[:from].to_s, "jordan@example.com"
  end

  test "includes the sender, category, subject, message and inbox link" do
    email = deliver
    body = email.text_part.body.to_s + email.html_part.body.to_s

    assert_includes email.subject, "Question about coaching sessions"
    assert_includes body, "Jordan Smith"
    assert_includes body, "jordan@example.com"
    assert_includes body, "General enquiry"
    assert_includes body, "I would like more information about the available sessions."
    assert_includes body, "/settings/contact-messages/#{@message.id}"
  end

  test "is multipart with a readable plain-text alternative" do
    email = deliver

    assert email.multipart?
    assert_includes email.text_part.body.to_s, "I would like more information"
    assert_includes email.text_part.body.to_s, "General enquiry"
  end

  test "escapes user-controlled content in the HTML part" do
    message = ContactMessage.create!(
      name: "<script>alert('x')</script>",
      email: "unsafe@example.com",
      contact_type: "other",
      subject: "Hello <b>there</b>",
      message: "<img src=x onerror=alert(1)>"
    )

    html = deliver(message).html_part.body.to_s

    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&lt;img"
    refute_includes html, "<script>alert"
    refute_includes html, "<img src=x"
  end

  private

  def restore_env(key, value)
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end
