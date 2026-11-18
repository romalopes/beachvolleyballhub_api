require "test_helper"

# Recipient parsing for contact-form notifications (IDENTITY-259).
#
# Misconfiguration must degrade, not crash: commas, whitespace, duplicates and
# typos are all handled, and header-injection material never becomes a recipient.
class ContactRecipientsTest < ActiveSupport::TestCase
  def env_with(value) = { ContactRecipients::ENV_KEY => value }

  test "parses a comma-separated list, trimming whitespace" do
    env = env_with(" support@beachvolleyballhub.com , admin@beachvolleyballhub.com ")

    assert_equal [ "support@beachvolleyballhub.com", "admin@beachvolleyballhub.com" ],
                 ContactRecipients.list(env)
  end

  test "removes duplicates case-insensitively, keeping the first spelling" do
    env = env_with("Support@Example.com,support@example.com,SUPPORT@EXAMPLE.COM")

    assert_equal [ "Support@Example.com" ], ContactRecipients.list(env)
  end

  test "ignores invalid and blank entries" do
    env = env_with("good@example.com,,not-an-email, ,also-bad@,good2@example.com")

    assert_equal [ "good@example.com", "good2@example.com" ], ContactRecipients.list(env)
    assert_equal [ "not-an-email", "also-bad@" ], ContactRecipients.invalid(env)
  end

  test "rejects addresses containing CR/LF" do
    env = env_with("good@example.com\r\nBcc: evil@example.com")

    assert_empty ContactRecipients.list(env)
  end

  test "an unset or empty variable means not configured" do
    assert_empty ContactRecipients.list({})
    assert_empty ContactRecipients.list(env_with("   "))
    assert_not ContactRecipients.configured?({})
  end

  test "configured? is true when at least one recipient is valid" do
    assert ContactRecipients.configured?(env_with("support@example.com"))
    assert_not ContactRecipients.configured?(env_with("nope"))
  end
end
