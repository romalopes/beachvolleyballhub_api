# Per-account notification channel switches (IDENTITY-249 phase 7).
#
# A missing row means "defaults" (in-app on, email off) rather than an error, so
# the system needs no backfill for existing accounts: `NotificationPreference.for`
# materialises a row on first write.
class NotificationPreference < ApplicationRecord
  EMAIL_CADENCES = %w[immediate daily weekly none].freeze

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :email_cadence, inclusion: { in: EMAIL_CADENCES }
  validate :muted_event_types_is_an_array

  # Whether an event of this type should be written as an in-app notification for
  # this account. Email delivery is a separate concern (see the email phase): a
  # muted in-app type does not silently mute email, and vice versa.
  def event_enabled?(event_type)
    in_app_enabled? && !muted_event_types.include?(event_type.to_s)
  end

  private

  def muted_event_types_is_an_array
    errors.add(:muted_event_types, "must be an array") unless muted_event_types.is_a?(Array)
  end
end
