# One in-app notification for one recipient Account.
#
# This is the durable source of truth for the bell and the inbox. Delivery
# channels (email, later push) read their own columns on the same row, so a
# channel can fail and retry without the in-app record ever being lost.
#
# `event_key` is unique per account (see the migration): publishers use it as the
# idempotency key, so replaying the same workflow transition can never create a
# duplicate for the same recipient.
class Notification < ApplicationRecord
  belongs_to :account
  belongs_to :actor_account, class_name: "Account", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :event_type, :event_key, :title, :message, presence: true
  # Uniqueness is enforced by the (account_id, event_key) index rather than a
  # model validation: Notifications::Publisher relies on `create_or_find_by!`,
  # which detects the database's unique-violation to resolve a replay safely. A
  # validation would raise before the insert and defeat that.

  scope :by_recency, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: read_at || Time.current)
  end
end
