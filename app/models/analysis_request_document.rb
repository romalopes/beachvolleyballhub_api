class AnalysisRequestDocument < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_documents
  belongs_to :uploaded_by, class_name: "Account", optional: true
  has_one_attached :file

  validates :title, presence: true
  validates :document_type, inclusion: { in: %w[report annotated_video raw_video other] }
end