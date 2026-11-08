class Discipline < ApplicationRecord
  include Sluggable
  source_column :name

  has_many :skills, dependent: :destroy
  # An in-use discipline is never silently deleted: the foreign keys from
  # `assessments.discipline_id` and `assessment_categories.discipline_id` refuse
  # the row at the database level (no `dependent:` option here on purpose — the
  # existing delete test pins ActiveRecord::InvalidForeignKey, and adding
  # `restrict_with_error` would downgrade that to a soft validation error).
  has_many :assessment_categories

  validates :name, presence: true, uniqueness: true

  def to_param
    slug
  end
end
