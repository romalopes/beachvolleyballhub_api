# Authorization for comments attached to an analysis.
class AnalysisCommentPolicy < ApplicationPolicy
  def destroy?
    admin? || user.present? && record.author_id == user.id
  end
end
