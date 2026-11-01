# Authorization rules for assessment-session operations shared by other domains.
class AssessmentSessionPolicy < ApplicationPolicy
  # Linking an assessment session exposes its result context through an analysis,
  # so only the established session managers may create that relationship.
  def link_to_analysis?
    admin? || curator? || creator? || assigned_coach?
  end

  private

  def creator? = user.present? && record.created_by_id == user.id
  def assigned_coach? = user.present? && record.coach_profile&.account_id == account&.id
end
