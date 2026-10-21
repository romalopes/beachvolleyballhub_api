class CreateTrainingSeries < ActiveRecord::Migration[8.1]
  # A recurrence definition plus the defaults captured when the series was
  # created. Sessions generated from it stay independent records; the series
  # only drives generation and grouping.
  def change
    create_table :training_series do |t|
      t.references :training_template, null: false,
                                       foreign_key: { to_table: :training_templates, on_delete: :restrict }
      t.references :organisation, null: true, foreign_key: { to_table: :organisations, on_delete: :nullify }
      t.references :created_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      t.string :frequency, null: false, default: "weekly"
      t.integer :interval, null: false, default: 1
      # Lower-case day tokens (mon..sun). Kept as an array so the UI can offer a
      # multi-weekday picker without a join table.
      t.string :weekdays, array: true, null: false, default: []
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.time :local_start_time, null: false
      t.integer :duration_minutes, null: false
      # IANA identifier, e.g. "Australia/Sydney". The application default time
      # zone is UTC, so the zone must travel with the rule.
      t.string :time_zone, null: false, default: "Australia/Sydney"

      # active -> generation allowed; stopped -> recurrence ended, existing
      # sessions are untouched.
      t.string :status, null: false, default: "active"
      t.date :generated_through
      t.jsonb :defaults_snapshot, null: false, default: {}
      t.datetime :last_generated_at
      t.datetime :stopped_at

      t.timestamps
    end

    add_index :training_series, :status
    add_index :training_series, :starts_on
    add_index :training_series, %i[training_template_id status]

    add_check_constraint :training_series,
                         "frequency IN ('weekly')",
                         name: "training_series_frequency"
    add_check_constraint :training_series,
                         "interval >= 1",
                         name: "training_series_interval_positive"
    add_check_constraint :training_series,
                         "ends_on >= starts_on",
                         name: "training_series_ends_on_after_starts_on"
    add_check_constraint :training_series,
                         "duration_minutes > 0",
                         name: "training_series_duration_positive"
    add_check_constraint :training_series,
                         "array_length(weekdays, 1) >= 1",
                         name: "training_series_weekdays_present"
    add_check_constraint :training_series,
                         "weekdays <@ ARRAY['mon','tue','wed','thu','fri','sat','sun']::varchar[]",
                         name: "training_series_weekdays_valid"
    add_check_constraint :training_series,
                         "status IN ('active', 'stopped')",
                         name: "training_series_status"
  end
end
