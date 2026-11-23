class AddPlayerProfileToAnalysisRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :analysis_requests, :player_profile, null: true, foreign_key: true
  end
end
