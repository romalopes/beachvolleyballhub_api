class AddExternalUrlToAnalysisRequestVideos < ActiveRecord::Migration[8.1]
  def change
    # An external video may reference either a catalogue Video row (video_id) or
    # a free-form provider URL supplied by the submitter.
    add_column :analysis_request_videos, :external_url, :string
  end
end
