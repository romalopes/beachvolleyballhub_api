# In-app notification persistence for the notification system (IDENTITY-249).
#
# Two tables:
#   * notifications            — one row per recipient ("account"), the durable
#     source of truth the bell and inbox read from. Delivery channels are
#     independent columns (`read_at` for the feed, `emailed_at`/`email_*` for the
#     email outbox added in a later phase), so a channel failing never loses the
#     in-app record.
#   * notification_preferences — per-account channel switches. A missing row
#     means "defaults" (in-app on, email off), so existing accounts need no
#     backfill.
#
# `event_key` is the dedupe identity: it is unique per recipient, so replaying
# the same workflow transition can never create a second row for the same
# person. `notifiable` is polymorphic so a notification can point at a training,
# an organisation, a comment, and so on without a new table per target.
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      # The account that caused the event (nullable: system/automatic events have
      # no actor, and the actor account may later be deleted).
      t.references :actor_account, foreign_key: { to_table: :accounts, on_delete: :nullify }
      t.references :notifiable, polymorphic: true
      # Stable machine-readable kind, e.g. "training.cancelled". The UI and the
      # preference filters key on this, never on the human title.
      t.string :event_type, null: false
      t.string :event_key, null: false
      t.string :title, null: false
      t.text :message, null: false
      # Internal SPA route the notification opens. Only ever an application path,
      # never an absolute URL, so it cannot be used as an open redirect.
      t.string :target_path
      t.string :target_label
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at
      t.datetime :emailed_at
      t.datetime :email_failed_at
      t.text :email_error
      t.timestamps
    end

    # One notification per recipient per event key: the idempotency guard.
    add_index :notifications, [ :account_id, :event_key ], unique: true
    # The inbox query (unread count + newest-first list) walks this index.
    add_index :notifications, [ :account_id, :read_at, :created_at ], name: "index_notifications_inbox"
    add_index :notifications, [ :event_type, :created_at ]

    create_table :notification_preferences do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.boolean :in_app_enabled, null: false, default: true
      t.boolean :email_enabled, null: false, default: false
      t.string :email_cadence, null: false, default: "immediate"
      t.jsonb :muted_event_types, null: false, default: []
      t.timestamps
    end

    add_check_constraint :notification_preferences,
                         "email_cadence IN ('immediate', 'daily', 'weekly', 'none')",
                         name: "notification_preferences_email_cadence"
  end
end
