class AddWebsiteToOrganisations < ActiveRecord::Migration[8.1]
  def change
    add_column :organisations, :website, :string
    add_index :organisations, :website
  end
end