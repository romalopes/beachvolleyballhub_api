class RemoveCityStateCountryFromTournaments < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE tournaments
      SET location_name = city
      WHERE (location_name IS NULL OR BTRIM(location_name) = '')
        AND city IS NOT NULL
        AND BTRIM(city) <> ''
    SQL

    remove_column :tournaments, :city, :string
    remove_column :tournaments, :state, :string
    remove_column :tournaments, :country, :string
  end

  def down
    add_column :tournaments, :city, :string
    add_column :tournaments, :state, :string
    add_column :tournaments, :country, :string
  end
end