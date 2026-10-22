class AnalysisVideo < ApplicationRecord
  SOURCE_TYPES = %w[external upload].freeze
  MAX_UPLOAD_SIZE = ENV.fetch("ANALYSIS_VIDEO_MAX_BYTES", 500.megabytes).to_i

  belongs_to :analysis, inverse_of: :analysis_videos
  belongs_to :video, optional: true
  has_one_attached :file
  has_many :analysis_annotations, -> { order(:timestamp_seconds, :id) }, dependent: :destroy, inverse_of: :analysis_video

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :source_is_consistent
  validate :uploaded_file_is_safe
  before_validation :assign_position

  def external? = source_type == "external"
  def upload? = source_type == "upload"

  private

  def assign_position
    self.position = (analysis&.analysis_videos&.maximum(:position) || -1) + 1 if position.nil?
  end

  def source_is_consistent
    errors.add(:video, "is required for an external video") if external? && video.nil?
    errors.add(:file, "is required for an uploaded video") if upload? && !file.attached?
    errors.add(:video, "must be blank for an uploaded video") if upload? && video_id.present?
  end

  def uploaded_file_is_safe
    return unless file.attached?

    errors.add(:file, "must be a video") unless file.blob.content_type.to_s.start_with?("video/")
    errors.add(:file, "is too large") if file.blob.byte_size > MAX_UPLOAD_SIZE
  end
end