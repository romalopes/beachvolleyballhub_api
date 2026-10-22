class CreateVideoAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :analyses do |t|
      t.string :title, null: false
      t.text :summary
      t.string :status, null: false, default: "draft"
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :assigned_coach_profile, foreign_key: { to_table: :coach_profiles, on_delete: :nullify }
      t.references :organisation, foreign_key: { on_delete: :nullify }
      t.references :group, foreign_key: { on_delete: :nullify }
      t.references :training_session, foreign_key: { on_delete: :nullify }
      t.references :tournament, foreign_key: { on_delete: :nullify }
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
    end
    add_index :analyses, [:status, :updated_at]
    add_check_constraint :analyses, "status IN ('draft', 'published', 'archived')", name: "analyses_status"
    add_check_constraint :analyses, "status <> 'published' OR published_at IS NOT NULL", name: "analyses_published_at"
    add_check_constraint :analyses, "status <> 'archived' OR archived_at IS NOT NULL", name: "analyses_archived_at"

    create_table :analysis_participants do |t|
      t.references :analysis, null: false, foreign_key: { on_delete: :cascade }
      t.references :player_profile, null: false, foreign_key: { on_delete: :restrict }
      t.text :notes
      t.timestamps
    end
    add_index :analysis_participants, [:analysis_id, :player_profile_id], unique: true, name: "index_analysis_participants_unique"

    create_table :analysis_videos do |t|
      t.references :analysis, null: false, foreign_key: { on_delete: :cascade }
      t.references :video, foreign_key: { on_delete: :nullify }
      t.string :source_type, null: false
      t.string :title
      t.text :description
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :analysis_videos, [:analysis_id, :position]
    add_check_constraint :analysis_videos, "source_type IN ('external', 'upload')", name: "analysis_videos_source_type"
    add_check_constraint :analysis_videos, "(source_type = 'external' AND video_id IS NOT NULL) OR (source_type = 'upload' AND video_id IS NULL)", name: "analysis_videos_source"

    create_table :analysis_annotations do |t|
      t.references :analysis_video, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :player_profile, foreign_key: { on_delete: :nullify }
      t.integer :timestamp_seconds, null: false
      t.text :body, null: false
      t.timestamps
    end
    add_index :analysis_annotations, [:analysis_video_id, :timestamp_seconds]
    add_check_constraint :analysis_annotations, "timestamp_seconds >= 0", name: "analysis_annotations_timestamp"

    create_table :analysis_comments do |t|
      t.references :analysis, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :parent, foreign_key: { to_table: :analysis_comments, on_delete: :cascade }
      t.text :body, null: false
      t.timestamps
    end
    add_index :analysis_comments, [:analysis_id, :created_at]

    create_table :analysis_assessment_sessions do |t|
      t.references :analysis, null: false, foreign_key: { on_delete: :cascade }
      t.references :assessment_session, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :analysis_assessment_sessions, [:analysis_id, :assessment_session_id], unique: true, name: "index_analysis_assessment_sessions_unique"
  end
end