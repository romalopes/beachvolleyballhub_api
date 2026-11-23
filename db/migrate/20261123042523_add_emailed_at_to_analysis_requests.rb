class AddEmailedAtToAnalysisRequests < ActiveRecord::Migration[8.1]
  def change
    # Delivery bookkeeping for the two submission emails. Kept separate per
    # channel so a crew failure can be retried without re-notifying the
    # submitter (and vice versa).
    add_column :analysis_requests, :crew_emailed_at, :datetime
    add_column :analysis_requests, :submitter_emailed_at, :datetime
  end
end
