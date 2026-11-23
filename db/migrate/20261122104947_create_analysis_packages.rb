class CreateAnalysisPackages < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_packages do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :name, null: false
      t.text :description
      t.integer :price_cents, default: 0, null: false
      t.integer :max_videos, default: 1, null: false
      t.integer :max_duration_minutes, default: 30, null: false
      t.boolean :includes_annotated_video, default: false, null: false
      t.boolean :includes_written_report, default: true, null: false
      t.boolean :includes_consultation, default: false, null: false
      t.integer :turnaround_days, default: 7, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE analysis_packages
        ADD CONSTRAINT analysis_packages_price_cents_check
        CHECK (price_cents >= 0);
    SQL
  end
end
