class CreateWeatherShareSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_share_snapshots do |t|
      t.references :account, null: false, foreign_key: true
      t.string :public_token, null: false, index: { unique: true }
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.string :location_name, null: false
      t.datetime :forecast_target_time
      t.string :timezone
      t.jsonb :weather_data, null: false
      t.integer :volleyball_score
      t.string :volleyball_label
      t.jsonb :volleyball_warnings, default: []
      t.jsonb :volleyball_advice, default: []
      t.boolean :volleyball_safety_override, default: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.string :image_url
      t.timestamps
    end

    add_index :weather_share_snapshots, :expires_at
    add_index :weather_share_snapshots, :revoked_at
    add_index :weather_share_snapshots, [:account_id, :created_at]
  end
end