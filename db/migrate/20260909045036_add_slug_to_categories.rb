class AddSlugToCategories < ActiveRecord::Migration[8.1]
  class Category < ActiveRecord::Base
    self.table_name = "categories"
  end

  def change
    add_column :categories, :slug, :string
    add_index :categories, :slug, unique: true
    Category.reset_column_information
    Category.find_each(&:save!)
  end
end

