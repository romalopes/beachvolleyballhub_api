# Authorization for the reusable video library.
#
# A Video has a creator, a visibility and a publication status. Public reads
# expose only `published` + `shared`; the owner or an admin may edit/delete it.
class VideoPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.published_and_shared
    end
  end

  def index?   = true
  def show?    = record.published_and_shared? || manager?
  def create?  = coach? || admin?
  def update?  = manager?
  def destroy? = manager?

  private

  def manager? = admin? || user == record.created_by
end
