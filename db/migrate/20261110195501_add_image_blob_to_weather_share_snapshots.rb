class AddImageBlobToWeatherShareSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_reference :weather_share_snapshots, :image_blob, foreign_key: { to_table: :active_storage_blobs }, null: true
  end
end