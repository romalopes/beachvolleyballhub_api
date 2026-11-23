class CreateAnalysisRequestInternalNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_internal_notes do |t|
      t.references :analysis_request, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      t.text :body, null: false
      t.timestamps
    end

    add_index :analysis_request_internal_notes, [:analysis_request_id, :created_at]
  end
end
