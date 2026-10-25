class CreateLocationDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :location_type, null: false, default: "beach"
      t.string :formatted_address
      t.string :locality
      t.string :administrative_area
      t.string :country_code, limit: 2
      t.string :timezone
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :status, null: false, default: "active"
      t.string :verification_status, null: false, default: "proposed"
      t.string :geocoding_status, null: false, default: "not_requested"
      t.string :source
      t.string :source_reference
      t.string :coordinate_source
      t.references :proposed_by_account, foreign_key: { to_table: :accounts }
      t.references :verified_by_account, foreign_key: { to_table: :accounts }
      t.datetime :verified_at
      t.datetime :archived_at
      t.references :merged_into, foreign_key: { to_table: :locations }
      t.text :internal_notes
      t.timestamps
    end

    add_index :locations, :normalized_name
    add_index :locations, %i[locality administrative_area country_code], name: "index_locations_on_locality_scope"
    add_index :locations, %i[status verification_status]
    add_check_constraint :locations, "latitude IS NULL OR latitude BETWEEN -90 AND 90", name: "locations_latitude_range"
    add_check_constraint :locations, "longitude IS NULL OR longitude BETWEEN -180 AND 180", name: "locations_longitude_range"
    add_check_constraint :locations, "(latitude IS NULL) = (longitude IS NULL)", name: "locations_coordinates_pair"
    add_check_constraint :locations, "status IN ('active', 'archived', 'merged')", name: "locations_status"
    add_check_constraint :locations, "verification_status IN ('proposed', 'verified', 'rejected')", name: "locations_verification_status"
    add_check_constraint :locations, "geocoding_status IN ('not_requested', 'pending', 'resolved', 'failed', 'manual')", name: "locations_geocoding_status"

    create_table :location_aliases do |t|
      t.references :location, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :source
      t.timestamps
    end
    add_index :location_aliases, :normalized_name
    add_index :location_aliases, %i[location_id normalized_name], unique: true,
              name: "index_location_aliases_unique_name"

    create_table :courts do |t|
      t.references :location, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.text :access_instructions
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :courts, %i[location_id normalized_name], unique: true
    add_check_constraint :courts, "latitude IS NULL OR latitude BETWEEN -90 AND 90", name: "courts_latitude_range"
    add_check_constraint :courts, "longitude IS NULL OR longitude BETWEEN -180 AND 180", name: "courts_longitude_range"
    add_check_constraint :courts, "(latitude IS NULL) = (longitude IS NULL)", name: "courts_coordinates_pair"
    add_check_constraint :courts, "status IN ('active', 'archived')", name: "courts_status"

    create_table :organisation_locations do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.text :notes
      t.timestamps
    end
    add_index :organisation_locations, %i[organisation_id location_id], unique: true,
              name: "index_organisation_locations_unique"

    add_reference :organisations, :default_location, foreign_key: { to_table: :locations }
    add_reference :groups, :default_location, foreign_key: { to_table: :locations }

    add_column :training_sessions, :location_id, :bigint
    add_index :training_sessions, :location_id
    add_foreign_key :training_sessions, :locations
    add_reference :training_sessions, :court, foreign_key: true

    add_reference :tournaments, :location, foreign_key: true
    add_reference :tournaments, :court, foreign_key: true
    add_column :tournaments, :location_detail, :string
  end
end
