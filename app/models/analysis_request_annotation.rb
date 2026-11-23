# A coach's timestamped note attached to one video of an analysis request
# (IDENTITY-265, coach workspace). Deliberately separate from AnalysisAnnotation,
# which belongs to the internal Analysis-of-Players feature.
class AnalysisRequestAnnotation < ApplicationRecord
  ANNOTATION_TYPES = %w[text drawing telestration].freeze

  belongs_to :analysis_request_video, inverse_of: :analysis_request_annotations
  belongs_to :author, class_name: "User"

  validates :body, presence: true, length: { maximum: 2_000 }
  validates :timestamp_seconds,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :annotation_type, inclusion: { in: ANNOTATION_TYPES }
end