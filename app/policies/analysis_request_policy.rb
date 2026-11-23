# Authorization rules for Analysis Requests (IDENTITY-265).
#
# The "user" here is a User (Pundit's pundit_user = Current.user); the
# submitter identity is reached through `user.account`. Guests never reach the
# policy for private actions because the controller requires authentication,
# but `create?` must allow them (guest submissions are public).
class AnalysisRequestPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless signed_in?

    staff? || owner? || assigned_coach?
  end

  def create?
    true
  end

  def update?
    return false unless signed_in?

    staff? ||
      (owner? && %w[submitted under_review].include?(record.workflow_status))
  end

  def destroy?
    staff?
  end

  def submit? = create?
  def accept? = staff?
  def reject? = staff?
  def quote? = staff?
  def assign_coach? = staff?
  def mark_invoice_sent? = staff?
  def mark_paid? = staff?
  def start_work? = staff? || assigned_coach?
  def complete? = staff? || assigned_coach?
  def cancel? = staff?
  def add_message? = show?
  def add_internal_note? = staff?
  def link_assessment_session? = staff?
  def upload_deliverable? = staff? || assigned_coach?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.present? && (user.admin? || user.curator?)
      return scope.for_account(user.account) if user&.account

      scope.none
    end
  end

  private

  def signed_in? = user.present?
  def staff? = signed_in? && (user.admin? || user.curator?)

  def owner?
    account_id = user.account&.id
    account_id.present? && record.account_id == account_id
  end

  def assigned_coach?
    account_id = user.account&.id
    account_id.present? && record.assigned_coach_profile&.account_id == account_id
  end
end