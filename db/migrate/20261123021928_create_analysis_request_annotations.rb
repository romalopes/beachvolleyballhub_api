class CreateAnalysisRequestAnnotations < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_annotations do |t|
      t.references :analysis_request_video, null: false, foreign_key: true, index: true
      t.references :author, null: false, foreign_key: { to_table: :users }, index: true
      t.integer :timestamp_seconds, null: false, default: 0
      t.text :body, null: false
      t.string :annotation_type, null: false, default: "text"
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE analysis_request_annotations
        ADD CONSTRAINT analysis_request_annotations_annotation_type_check
        CHECK (annotation_type IN ('text','drawing','telestration'));
    SQL

    execute <<-SQL
      ALTER TABLE analysis_request_annotations
        ADD CONSTRAINT analysis_request_annotations_timestamp_check
        CHECK (timestamp_seconds >= 0);
    SQL

    add_index :analysis_request_annotations, [ :analysis_request_video_id, :timestamp_seconds ],
              name: "index_analysis_request_annotations_on_video_and_timestamp"
  end
end
