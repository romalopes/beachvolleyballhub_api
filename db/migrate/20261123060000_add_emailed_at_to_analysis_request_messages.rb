# Tracks per-message email delivery (IDENTITY-265).
#
# A message can trigger one notification and one email; the timestamp makes the
# delivery job restart-safe (a retry never double-sends) without suppressing an
# intentional later message.
class AddEmailedAtToAnalysisRequestMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :analysis_request_messages, :emailed_at, :datetime
  end
end
