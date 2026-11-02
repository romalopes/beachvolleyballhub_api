class CreateWeatherAdvisorPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_advisor_preferences do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.integer :wind_weight, null: false, default: 40
      t.integer :temperature_weight, null: false, default: 20
      t.integer :rain_weight, null: false, default: 25
      t.integer :uv_weight, null: false, default: 5
      t.integer :humidity_weight, null: false, default: 10
      t.timestamps
    end

    %i[wind temperature rain uv humidity].each do |factor|
      column = "#{factor}_weight"
      add_check_constraint :weather_advisor_preferences,
                           "#{column} BETWEEN 0 AND 100",
                           name: "weather_advisor_preferences_#{column}_range"
    end

    add_check_constraint :weather_advisor_preferences,
                         "wind_weight + temperature_weight + rain_weight + uv_weight + humidity_weight = 100",
                         name: "weather_advisor_preferences_weights_total"
  end
end
