class CreateAnalysisRequestAssessmentSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_request_assessment_sessions do |t|
      t.references :analysis_request, null: false, foreign_key: true, index: true
      t.references :assessment_session, null: false, foreign_key: true, index: true
      t.timestamps
    end

    add_index :analysis_request_assessment_sessions, [:analysis_request_id, :assessment_session_id], unique: true
  end
end
