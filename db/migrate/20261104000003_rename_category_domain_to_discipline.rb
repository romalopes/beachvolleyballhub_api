class RenameCategoryDomainToDiscipline < ActiveRecord::Migration[8.1]
  def up
    rename_table :categories, :disciplines
    rename_table :category_customs, :discipline_customs

    rename_column :skills, :category_id, :discipline_id
    rename_column :assessments, :category_id, :discipline_id
    rename_column :assessments, :custom_category, :custom_discipline
    rename_column :assessment_categories, :category_id, :discipline_id
    rename_column :assessment_categories, :category_custom_id, :discipline_custom_id

    execute <<~SQL.squish
      ALTER TABLE assessments
      RENAME CONSTRAINT assessments_category_xor_custom_category
      TO assessments_discipline_xor_custom_discipline
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE assessments
      RENAME CONSTRAINT assessments_discipline_xor_custom_discipline
      TO assessments_category_xor_custom_category
    SQL

    rename_column :assessment_categories, :discipline_custom_id, :category_custom_id
    rename_column :assessment_categories, :discipline_id, :category_id
    rename_column :assessments, :custom_discipline, :custom_category
    rename_column :assessments, :discipline_id, :category_id
    rename_column :skills, :discipline_id, :category_id

    rename_table :discipline_customs, :category_customs
    rename_table :disciplines, :categories
  end
end

