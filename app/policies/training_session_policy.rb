# Authorization for training sessions.
#
# Visibility and management are separate concerns:
#   * index/show return only what the current user may see (drafts are private
#     to coaches/curators/admins) — see `TrainingSession#visible_to_user?`.
#   * create/update/destroy require a training manager (coach/curator/admin).
#     This is deliberately NOT based on `created_by_id`, because trainings are
#     shared schedule resources.
class TrainingSessionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.visible_to(user)
  end

  def index?   = true
  def show?    = record.visible_to_user?(user)
  def create?  = content_manager?
  def update?  = content_manager?
  def destroy? = content_manager?
end
