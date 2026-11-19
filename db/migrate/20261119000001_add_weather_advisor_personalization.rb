class AddWeatherAdvisorPersonalization < ActiveRecord::Migration[8.1]
  def change
    add_column :weather_advisor_preferences, :conditions, :jsonb, null: false, default: {}
    add_column :weather_advisor_preferences, :wind_direction_preferences, :jsonb, null: false, default: {}

    create_table :weather_advisor_location_preferences do |t|
      t.references :account, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.jsonb :wind_direction_preferences, null: false, default: {}
      t.timestamps
    end
    add_index :weather_advisor_location_preferences, %i[account_id location_id], unique: true,
              name: "index_weather_advisor_location_preferences_unique"
  end
end