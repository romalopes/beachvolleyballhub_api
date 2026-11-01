# Authorization for the skill catalogue.
#
# Skills have a creator, a visibility and a publication status. Public reads
# expose only `published` + `shared`; a hidden skill is visible to its creator
# and manageable by the owner or an admin.
class SkillPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.published_and_shared
    end
  end

  def index? = true
  def show?  = record.published_and_shared? || manager?
  def create? = coach? || admin?
  def update? = manager?
  def destroy? = manager?

  private

  # An admin, or the record's creator. `user == record.created_by` deliberately
  # matches nil == nil so a legacy ownerless catalogue row stays manageable —
  # preserving the behaviour the existing controller tests pin.
  def manager? = admin? || user == record.created_by
end
