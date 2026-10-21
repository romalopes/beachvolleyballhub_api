class AddRecurringTrainingFieldsToTrainingSessions < ActiveRecord::Migration[8.1]
  # Every column is additive/nullable so existing one-off sessions keep working
  # without a backfill. A session that belongs to a series carries a stable
  # recurrence_key even after cancellation (tombstone), which the partial
  # unique index protects against regeneration races.
  def change
    add_reference :training_sessions, :training_series, null: true,
                  foreign_key: { to_table: :training_series, on_delete: :restrict }
    add_reference :training_sessions, :training_template, null: true,
                  foreign_key: { to_table: :training_templates, on_delete: :restrict }
    add_reference :training_sessions, :organisation, null: true,
                  foreign_key: { to_table: :organisations, on_delete: :nullify }
    add_reference :training_sessions, :group, null: true,
                  foreign_key: { to_table: :groups, on_delete: :nullify }
    add_reference :training_sessions, :coach_profile, null: true,
                  foreign_key: { to_table: :coach_profiles, on_delete: :nullify }
    add_reference :training_sessions, :cancelled_by, null: true,
                  foreign_key: { to_table: :users, on_delete: :nullify }

    add_column :training_sessions, :capacity, :integer
    add_column :training_sessions, :level, :string
    add_column :training_sessions, :location_detail, :string
    # "YYYY-MM-DDTHH:MM" in the series time zone: the intended local slot, not
    # the mutable actual starts_at. Moving an occurrence does not change it.
    add_column :training_sessions, :recurrence_key, :string
    add_column :training_sessions, :original_starts_at, :datetime
    add_column :training_sessions, :override_fields, :jsonb, null: false, default: {}
    add_column :training_sessions, :cancellation_reason, :text
    add_column :training_sessions, :cancelled_at, :datetime

    add_index :training_sessions, %i[training_series_id starts_at],
              name: "index_training_sessions_on_series_and_starts_at"
    add_index :training_sessions, %i[training_series_id recurrence_key],
              unique: true,
              where: "training_series_id IS NOT NULL AND recurrence_key IS NOT NULL",
              name: "index_training_sessions_on_series_and_recurrence_key"

    add_check_constraint :training_sessions,
                         "training_series_id IS NULL OR recurrence_key IS NOT NULL",
                         name: "training_sessions_series_requires_recurrence_key"
    add_check_constraint :training_sessions,
                         "capacity IS NULL OR capacity > 0",
                         name: "training_sessions_capacity_positive"
  end
end
