# Links each analysis video to the request video it was copied from
# (IDENTITY-265), so the analysis editor can point back at the submitted footage
# and the request keeps a per-video audit trail. Nullable: videos added directly
# in the analysis editor have no request source.
class AddAnalysisRequestVideoToAnalysisVideos < ActiveRecord::Migration[8.1]
  def change
    add_reference :analysis_videos, :analysis_request_video,
                  null: true, foreign_key: { on_delete: :nullify }, index: true
  end
end
