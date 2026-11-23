class CreateAnalysisRequestVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_videos do |t|
      t.references :analysis_request, null: false, foreign_key: true, index: true
      t.references :video, foreign_key: true, null: true, index: true
      t.string :source_type, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE analysis_request_videos
        ADD CONSTRAINT analysis_request_videos_source_type_check
        CHECK (source_type IN ('external','upload'));
    SQL

    add_index :analysis_request_videos, [:analysis_request_id, :position]
  end
end
