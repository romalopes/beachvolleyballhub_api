# Public contact enquiries from the Contact form (IDENTITY-259).
#
# One row per submission. There is deliberately **no** `user_id`: the form is
# open to anonymous visitors, and a message must never be linked to an Account,
# PlayerProfile, CoachProfile, Organisation, TrainingSession or Tournament based
# on untrusted form input.
#
# `emailed_at` / `notified_at` are delivery outbox markers, not sender data. The
# message row is written *before* any delivery is attempted (so a mail failure
# can never lose the message), and those two columns make a retried delivery job
# idempotent.
class CreateContactMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_messages do |t|
      t.string :name, null: false
      t.string :email, null: false
      # Validated against ContactMessage::CONTACT_TYPES — never an arbitrary
      # string supplied by the browser.
      t.string :contact_type, null: false
      t.string :subject, null: false
      # Plain text only; escaped whenever it is rendered.
      t.text :message, null: false
      # unread (default) | read | archived — see ContactMessage::STATUSES.
      t.string :status, null: false, default: "unread"
      t.datetime :read_at
      t.datetime :archived_at
      # Delivery state (Phase 2). NULL = not delivered yet.
      t.datetime :emailed_at
      t.datetime :notified_at
      t.timestamps
    end

    # Inbox queries: newest-first list filtered by status.
    add_index :contact_messages, [ :status, :created_at ]
    # The unfiltered "All" tab orders by created_at alone.
    add_index :contact_messages, :created_at
    # The contact-type filter.
    add_index :contact_messages, :contact_type
    # Unread badge / status counts (archived messages must not inflate them).
    add_index :contact_messages, [ :status, :archived_at ]

    add_check_constraint :contact_messages,
                         "status IN ('unread', 'read', 'archived')",
                         name: "contact_messages_status"
  end
end
