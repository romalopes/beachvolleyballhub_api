class CreateAnalysisRequestMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_messages do |t|
      t.references :analysis_request, null: false, foreign_key: true, index: true
      t.references :account, foreign_key: true, index: true
      t.references :user, foreign_key: true, index: true
      t.text :body, null: false
      t.boolean :from_submitter, default: false, null: false
      t.boolean :internal, default: false, null: false
      t.timestamps
    end

    add_index :analysis_request_messages, [:analysis_request_id, :created_at]
  end
end
