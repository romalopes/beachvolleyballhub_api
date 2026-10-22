class AnalysisAssessmentSession < ApplicationRecord
  belongs_to :analysis, inverse_of: :analysis_assessment_sessions
  belongs_to :assessment_session

  validates :assessment_session_id, uniqueness: { scope: :analysis_id }
end