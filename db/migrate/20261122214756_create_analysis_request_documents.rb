class CreateAnalysisRequestDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_documents do |t|
      t.references :analysis_request, null: false, foreign_key: true, index: true
      t.references :uploaded_by, foreign_key: { to_table: :accounts }, index: true
      t.string :title, null: false
      t.string :document_type, null: false
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE analysis_request_documents
        ADD CONSTRAINT analysis_request_documents_document_type_check
        CHECK (document_type IN ('report','annotated_video','raw_video','other'));
    SQL

    add_index :analysis_request_documents, [:analysis_request_id, :created_at]
  end
end
