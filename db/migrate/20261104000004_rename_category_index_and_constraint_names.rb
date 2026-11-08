class RenameCategoryIndexAndConstraintNames < ActiveRecord::Migration[8.1]
  def up
    rename_index :assessment_categories,
                 "index_assessment_categories_on_definition_and_category",
                 "index_assessment_categories_on_definition_and_discipline"
    rename_index :assessment_categories,
                 "index_assessment_categories_on_definition_and_custom",
                 "index_assessment_categories_on_definition_and_discipline_custom"
    rename_index :discipline_customs,
                 "index_category_customs_on_creator_and_name",
                 "index_discipline_customs_on_creator_and_name"

    execute <<~SQL.squish
      ALTER TABLE discipline_customs
      RENAME CONSTRAINT category_customs_visibility
      TO discipline_customs_visibility
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE discipline_customs
      RENAME CONSTRAINT discipline_customs_visibility
      TO category_customs_visibility
    SQL

    rename_index :discipline_customs,
                 "index_discipline_customs_on_creator_and_name",
                 "index_category_customs_on_creator_and_name"
    rename_index :assessment_categories,
                 "index_assessment_categories_on_definition_and_discipline_custom",
                 "index_assessment_categories_on_definition_and_custom"
    rename_index :assessment_categories,
                 "index_assessment_categories_on_definition_and_discipline",
                 "index_assessment_categories_on_definition_and_category"
  end
end

