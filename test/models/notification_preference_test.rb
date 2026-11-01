require "test_helper"

# Preference rules: defaults, the cadence vocabulary, and the mute check the
# publisher consults before writing an in-app row.
class NotificationPreferenceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "defaults to in-app on and email off when materialised" do
    preference = @account.create_notification_preference!

    assert preference.in_app_enabled?
    assert_not preference.email_enabled?
    assert_equal "immediate", preference.email_cadence
    assert_equal [], preference.muted_event_types
  end

  test "is unique per account" do
    @account.create_notification_preference!

    duplicate = NotificationPreference.new(account: @account)
    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :account_id
  end

  test "rejects an unknown cadence" do
    preference = NotificationPreference.new(account: @account, email_cadence: "hourly")
    assert_not preference.valid?
    assert_includes preference.errors.attribute_names, :email_cadence
  end

  test "rejects a non-array muted list" do
    preference = NotificationPreference.new(account: @account, muted_event_types: "training.cancelled")
    assert_not preference.valid?
    assert_includes preference.errors.attribute_names, :muted_event_types
  end

  test "event_enabled? honours the switch and the mute list" do
    preference = @account.create_notification_preference!(muted_event_types: [ "training.invited" ])

    assert preference.event_enabled?("training.cancelled")
    assert_not preference.event_enabled?("training.invited")

    preference.update!(in_app_enabled: false)
    assert_not preference.event_enabled?("training.cancelled")
  end

  test "destroying the account removes its preferences" do
    account = create_account!(first_name: "Pref", last_name: "Owner")
    account.create_notification_preference!

    assert_difference("NotificationPreference.where(account_id: #{account.id}).count", -1) do
      account.destroy
    end
  end
end
