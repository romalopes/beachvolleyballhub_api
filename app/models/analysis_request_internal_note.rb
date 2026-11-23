class AnalysisRequestInternalNote < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_internal_notes
  belongs_to :account

  validates :body, presence: true
end