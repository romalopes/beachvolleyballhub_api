class AnalysisComment < ApplicationRecord
  belongs_to :analysis, inverse_of: :analysis_comments
  belongs_to :author, class_name: "User"
  belongs_to :parent, class_name: "AnalysisComment", optional: true
  has_many :replies, class_name: "AnalysisComment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true, length: { maximum: 5_000 }
  validate :parent_belongs_to_analysis

  private

  def parent_belongs_to_analysis
    errors.add(:parent, "must belong to the same analysis") if parent && parent.analysis_id != analysis_id
  end
end