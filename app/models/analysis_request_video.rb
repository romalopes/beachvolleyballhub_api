class AnalysisRequestVideo < ApplicationRecord
  SOURCE_TYPES = %w[external upload].freeze
  MAX_UPLOAD_SIZE = ENV.fetch("ANALYSIS_REQUEST_VIDEO_MAX_BYTES", 500.megabytes).to_i

  belongs_to :analysis_request, inverse_of: :analysis_request_videos
  belongs_to :video, optional: true
  has_one_attached :file
  has_many :analysis_request_annotations, -> { order(:timestamp_seconds, :id) }, dependent: :destroy, inverse_of: :analysis_request_video

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :source_is_consistent
  validate :uploaded_file_is_safe
  before_validation :assign_position

  def external? = source_type == "external"
  def upload? = source_type == "upload"

  private

  # The column defaults to 0, so a bare `position.nil?` check would never fire
  # and every appended video would share position 0. Treat "unset" as nil or 0
  # and only keep an explicitly positive position.
  def assign_position
    return if position.present? && position.positive?

    self.position = (analysis_request&.analysis_request_videos&.maximum(:position) || -1) + 1
  end

  def source_is_consistent
    if external?
      errors.add(:base, "An external video needs a catalogue video or a URL") if video.nil? && external_url.blank?
      errors.add(:external_url, "must be an http(s) URL") if external_url.present? && !http_url?(external_url)
    end

    if upload?
      errors.add(:file, "is required for an uploaded video") if !file.attached?
      errors.add(:video, "must be blank for an uploaded video") if video_id.present?
      errors.add(:external_url, "must be blank for an uploaded video") if external_url.present?
    end
  end

  def http_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def uploaded_file_is_safe
    return unless file.attached?
    errors.add(:file, "must be a video") unless file.blob.content_type.to_s.start_with?("video/")
    errors.add(:file, "is too large") if file.blob.byte_size > MAX_UPLOAD_SIZE
  end
end