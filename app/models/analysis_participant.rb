class AnalysisParticipant < ApplicationRecord
  belongs_to :analysis, inverse_of: :analysis_participants
  belongs_to :player_profile

  validates :player_profile_id, uniqueness: { scope: :analysis_id }
end