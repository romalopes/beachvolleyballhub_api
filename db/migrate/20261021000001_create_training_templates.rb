class CreateTrainingTemplates < ActiveRecord::Migration[8.1]
  # Reusable training definition. A template is the "what we usually do"
  # record; it carries defaults only and never owns scheduled occurrences.
  # Archiving (rather than deleting) keeps historical sessions meaningful.
  def change
    create_table :training_templates do |t|
      t.string :name, null: false
      t.text :description
      t.references :organisation, null: true, foreign_key: { to_table: :organisations, on_delete: :nullify }
      t.references :group, null: true, foreign_key: { to_table: :groups, on_delete: :nullify }
      t.references :coach_profile, null: true, foreign_key: { to_table: :coach_profiles, on_delete: :nullify }
      t.string :location
      t.string :location_detail
      t.string :level
      t.integer :capacity
      t.integer :duration_minutes, null: false, default: 90
      # shared/private mirrors TrainingSession visibility so a template can be
      # used to create private sessions without a second concept.
      t.string :visibility, null: false, default: "shared"
      t.string :status, null: false, default: "active"
      # Audit only, exactly like TrainingSession#created_by: it is not an
      # ownership boundary.
      t.references :created_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    add_index :training_templates, :status
    add_index :training_templates, :name

    add_check_constraint :training_templates,
                         "status IN ('active', 'archived')",
                         name: "training_templates_status"
    add_check_constraint :training_templates,
                         "visibility IN ('shared', 'private')",
                         name: "training_templates_visibility"
    add_check_constraint :training_templates,
                         "capacity IS NULL OR capacity > 0",
                         name: "training_templates_capacity_positive"
    add_check_constraint :training_templates,
                         "duration_minutes > 0",
                         name: "training_templates_duration_positive"
  end
end
