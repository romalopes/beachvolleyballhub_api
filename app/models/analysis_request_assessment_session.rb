class AnalysisRequestAssessmentSession < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_assessment_sessions
  belongs_to :assessment_session, inverse_of: :analysis_request_assessment_sessions

  validates :analysis_request_id, uniqueness: { scope: :assessment_session_id }
end