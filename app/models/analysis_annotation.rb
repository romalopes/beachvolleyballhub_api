class AnalysisAnnotation < ApplicationRecord
  belongs_to :analysis_video, inverse_of: :analysis_annotations
  belongs_to :author, class_name: "User"
  belongs_to :player_profile, optional: true

  validates :body, presence: true, length: { maximum: 2_000 }
  validates :timestamp_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :player_participates

  private

  def player_participates
    return if player_profile.nil? || analysis_video.analysis.player_profile_ids.include?(player_profile_id)
    errors.add(:player_profile, "must participate in the analysis")
  end
end