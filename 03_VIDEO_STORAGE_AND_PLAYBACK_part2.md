## 3. Video Storage and Playback (continued)

### 3.5 AnalysisVideo Model Implementation
The `AnalysisVideo` model handles both external and uploaded videos:

```ruby
class AnalysisVideo < ApplicationRecord
  SOURCE_TYPES = %w[external upload].freeze
  MAX_UPLOAD_SIZE = ENV.fetch("ANALYSIS_VIDEO_MAX_BYTES", 500.megabytes).to_i

  belongs_to :analysis, inverse_of: :analysis_videos
  belongs_to :video, optional: true
  has_one_attached :file

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :source_is_consistent
  validate :uploaded_file_is_safe

  before_validation :assign_position

  def external?
    source_type == "external"
  end

  def upload?
    source_type == "upload"
  end

  private

  def assign_position
    self.position = (analysis.analysis_videos.maximum(:position) || -1) + 1 if position.nil?
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
```

### 3.6 Video Playback URL Generation
Playback URLs are generated based on the video source:

```ruby
def playback_url
  if upload? && file.attached?
    rails_blob_path(file, disposition: "inline", only_path: true)
  elsif external? && video.present?
    video.embed_url
  else
    nil
  end
end
```

### 3.7 Security Considerations for Video Access
- All video playback URLs are generated dynamically and require authentication
- External video URLs are validated and sanitized
- Uploaded videos are scanned for content type and size
- Access control is enforced through the `AnalysisPolicy` before generating URLs
- No direct links to storage buckets are exposed in the API
- All video access routes are protected by the same authorization checks as the analysis itself