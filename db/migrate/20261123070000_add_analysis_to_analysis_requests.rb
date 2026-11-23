# Links an approved analysis request to the Analysis the team works on
# (IDENTITY-265). One request has at most one analysis; deleting the analysis
# only unlinks it so the request keeps its history.
class AddAnalysisToAnalysisRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :analysis_requests, :analysis,
                  null: true, foreign_key: { on_delete: :nullify }, index: true
  end
end
