class AddSlugToLocations < ActiveRecord::Migration[8.1]
  class MigrationLocation < ActiveRecord::Base
    self.table_name = "locations"
  end

  def up
    add_column :locations, :slug, :string

    MigrationLocation.reset_column_information
    MigrationLocation.order(:id).find_each do |location|
      base = location.name.to_s.parameterize.presence || "location"
      slug = base
      suffix = 1

      while MigrationLocation.where(slug: slug).where.not(id: location.id).exists?
        suffix += 1
        slug = "#{base}-#{suffix}"
      end

      location.update_columns(slug: slug)
    end

    change_column_null :locations, :slug, false
    add_index :locations, :slug, unique: true
  end

  def down
    remove_index :locations, :slug
    remove_column :locations, :slug
  end
end