class AddIncludesAssessmentToAnalysisPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :analysis_packages, :includes_assessment, :boolean
  end
end
