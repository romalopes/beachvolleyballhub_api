class CreateAnalysisRequestInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_invoices do |t|
      t.references :analysis_request, null: false, foreign_key: true, index: true
      t.integer :amount_cents, null: false
      t.string :currency, default: "AUD", null: false
      t.datetime :sent_at
      t.datetime :paid_at
      t.string :status, default: "pending", null: false
      t.string :external_reference
      t.timestamps
    end

    execute <<-SQL
      ALTER TABLE analysis_request_invoices
        ADD CONSTRAINT analysis_request_invoices_amount_cents_check
        CHECK (amount_cents > 0);
    SQL

    execute <<-SQL
      ALTER TABLE analysis_request_invoices
        ADD CONSTRAINT analysis_request_invoices_status_check
        CHECK (status IN ('pending','sent','paid','overdue','cancelled','refunded'));
    SQL

    add_index :analysis_request_invoices, :status
    add_index :analysis_request_invoices, :sent_at
  end
end
