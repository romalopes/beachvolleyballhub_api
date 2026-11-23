class CreateAnalysisRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_requests do |t|
      t.references :account, foreign_key: true, null: true, index: true
      t.string :guest_name, null: true
      t.string :guest_email, null: true
      t.string :guest_access_token, null: true, index: { unique: true }
      t.string :reference, null: false, index: { unique: true }
      t.string :title, null: false, limit: 160
      t.text :description
      t.string :package_key, null: true
      t.integer :price_cents, default: 0, null: false
      t.string :workflow_status, null: false, default: "submitted"
      t.string :payment_status, null: false, default: "unpaid"
      t.references :assigned_coach_profile, foreign_key: { to_table: :coach_profiles }, null: true, index: true
      t.datetime :submitted_at, null: true
      t.datetime :accepted_at, null: true
      t.datetime :rejected_at, null: true
      t.text :rejection_reason
      t.datetime :invoice_sent_at, null: true
      t.datetime :paid_at, null: true
      t.datetime :work_started_at, null: true
      t.datetime :completed_at, null: true
      t.datetime :cancelled_at, null: true
      t.timestamps
    end

    # Check constraints for enum-like columns (Rails 8 convention)
    execute <<-SQL
      ALTER TABLE analysis_requests
        ADD CONSTRAINT analysis_requests_workflow_status_check
        CHECK (workflow_status IN ('submitted','under_review','accepted','rejected','quoted','awaiting_payment','in_progress','awaiting_submitter','completed','cancelled'));
    SQL

    execute <<-SQL
      ALTER TABLE analysis_requests
        ADD CONSTRAINT analysis_requests_payment_status_check
        CHECK (payment_status IN ('unpaid','invoice_sent','paid','overdue','cancelled','refunded','complimentary'));
    SQL

    add_index :analysis_requests, :workflow_status
    add_index :analysis_requests, :payment_status
    add_index :analysis_requests, [:account_id, :workflow_status]
    add_index :analysis_requests, [:guest_email, :guest_access_token]
  end
end
