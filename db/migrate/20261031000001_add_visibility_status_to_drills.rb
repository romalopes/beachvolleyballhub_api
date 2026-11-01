class AddVisibilityStatusToDrills < ActiveRecord::Migration[8.1]
  def change
    add_column :drills, :visibility, :string, null: false, default: "shared"
    add_column :drills, :status, :string, null: false, default: "draft"
    add_column :drills, :published_at, :datetime
    add_column :drills, :approved_at, :datetime
    add_column :drills, :approved_by_id, :bigint

    add_index :drills, :visibility
    add_index :drills, :status

    add_foreign_key :drills, :users, column: :approved_by_id
  end
end
