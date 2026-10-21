class AddStoppedReasonToTrainingSeries < ActiveRecord::Migration[8.1]
  # Stopping recurrence is an explicit, auditable decision. The reason explains
  # why generation ended without implying that existing sessions were cancelled.
  def change
    add_column :training_series, :stopped_reason, :text
  end
end
