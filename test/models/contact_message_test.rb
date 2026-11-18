require "test_helper"

# Model rules for public contact enquiries (IDENTITY-259).
#
# The important behaviour pinned here: only allow-listed categories are stored,
# the record carries no account/profile association, every value is trimmed, and
# the status transitions keep `read_at` / `archived_at` consistent and idempotent.
class ContactMessageTest < ActiveSupport::TestCase
  def build(attributes = {})
    ContactMessage.new({
      name: "Jordan Smith",
      email: "Jordan@Example.com",
      contact_type: "general",
      subject: "Question about sessions",
      message: "I would like more information."
    }.merge(attributes))
  end

  test "a valid enquiry saves with the default unread status" do
    message = build

    assert message.save, message.errors.full_messages.to_sentence
    assert_equal "unread", message.status
    assert_nil message.read_at
    assert_nil message.archived_at
  end

  test "there is no submitter association on the record" do
    # The public form must never link a message to an Account or profile: the
    # columns simply do not exist, so a future change cannot silently start
    # trusting form input for identity.
    refute ContactMessage.column_names.include?("user_id")
    refute ContactMessage.column_names.include?("account_id")
  end

  test "required attributes are enforced" do
    %i[name email contact_type subject message].each do |attribute|
      message = build(attribute => nil)
      assert_not message.valid?, "expected #{attribute} to be required"
      assert message.errors[attribute].any?
    end
  end

  test "an invalid email address is rejected" do
    assert_not build(email: "not-an-email").valid?
    assert_not build(email: "jordan@example.com\r\nBcc: evil@example.com").valid?
  end

  test "only allow-listed contact types are accepted" do
    assert build(contact_type: "training_tournament").valid?
    message = build(contact_type: "sales_pitch")
    assert_not message.valid?
    assert_includes message.errors[:contact_type], "is not included in the list"
  end

  test "maximum lengths are enforced" do
    assert_not build(name: "a" * 121).valid?
    assert_not build(email: "#{'a' * 250}@example.com").valid?
    assert_not build(subject: "a" * 181).valid?
    assert_not build(message: "a" * 10_001).valid?
  end

  test "values are trimmed and the email is normalised" do
    message = build(name: "  Jordan Smith  ", email: "  JORDAN@example.com ", subject: "  Hello  ",
                    contact_type: " GENERAL ", message: "\n  Body text  \n")

    assert message.valid?, message.errors.full_messages.to_sentence
    assert_equal "Jordan Smith", message.name
    assert_equal "jordan@example.com", message.email
    assert_equal "Hello", message.subject
    assert_equal "general", message.contact_type
    assert_equal "Body text", message.message
  end

  test "control characters are rejected in header-bound fields" do
    %i[name subject email].each do |attribute|
      message = build(attribute => "value\r\nInjected: header")
      assert_not message.valid?, "expected #{attribute} with CRLF to be rejected"
      assert_includes message.errors[attribute], "must not contain control characters"
    end
  end

  test "status must be one of the supported states" do
    assert_not build(status: "deleted").valid?
  end

  test "the contact type label is human readable" do
    assert_equal "Account or login support", build(contact_type: "account_access").contact_type_label
    assert_equal "Other", build(contact_type: "other").contact_type_label
  end

  # --- status transitions -----------------------------------------------------

  test "marking read records read_at and is idempotent" do
    message = build.tap(&:save!)

    message.mark_read!
    first_read_at = message.read_at

    assert_equal "read", message.status
    assert_not_nil first_read_at

    message.mark_read!
    assert_equal first_read_at, message.reload.read_at
  end

  test "marking unread clears read_at" do
    message = build.tap(&:save!)
    message.mark_read!

    message.mark_unread!

    assert_equal "unread", message.reload.status
    assert_nil message.read_at
  end

  test "archiving records archived_at" do
    message = build.tap(&:save!)

    message.archive!

    assert_equal "archived", message.reload.status
    assert_not_nil message.archived_at
  end

  test "read and unread unarchive a message" do
    message = build.tap(&:save!)
    message.archive!

    message.mark_read!

    assert_equal "read", message.reload.status
    assert_nil message.archived_at
  end

  test "apply_status! rejects an unknown status" do
    message = build.tap(&:save!)

    assert_raises(ActiveRecord::RecordInvalid) { message.apply_status!("deleted") }
    assert_equal "unread", message.reload.status
  end

  test "apply_status! applies each supported status" do
    message = build.tap(&:save!)

    message.apply_status!("read")
    assert message.reload.read?

    message.apply_status!("archived")
    assert message.reload.archived?

    message.apply_status!("unread")
    assert message.reload.unread?
  end

  # --- scopes -----------------------------------------------------------------

  test "by_recency returns the newest message first" do
    assert_equal [ contact_messages(:archived_feedback), contact_messages(:read_coaching),
                   contact_messages(:unread_general) ],
                 ContactMessage.by_recency.to_a
  end

  test "status scopes separate unread, read and archived messages" do
    assert_includes ContactMessage.unread, contact_messages(:unread_general)
    refute_includes ContactMessage.unread, contact_messages(:read_coaching)

    assert_includes ContactMessage.read_messages, contact_messages(:read_coaching)
    assert_includes ContactMessage.archived, contact_messages(:archived_feedback)
    refute_includes ContactMessage.not_archived, contact_messages(:archived_feedback)
  end

  test "matching searches name, email and subject case-insensitively" do
    assert_includes ContactMessage.matching("jordan"), contact_messages(:unread_general)
    assert_includes ContactMessage.matching("PRIYA@EXAMPLE"), contact_messages(:read_coaching)
    assert_includes ContactMessage.matching("calendar"), contact_messages(:archived_feedback)
    assert_empty ContactMessage.matching("no-such-enquiry")
  end

  test "matching treats LIKE wildcards literally" do
    assert_empty ContactMessage.matching("%")
    assert_empty ContactMessage.matching("_")
  end

  test "matching with a blank term returns the whole relation" do
    assert_equal ContactMessage.count, ContactMessage.matching("   ").count
  end
end
