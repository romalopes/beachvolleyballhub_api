# Authorization for skill disciplines.
#
# Disciplines are site-wide reference data: reads are public, and only an admin
# may create, rename or delete one. (The frontend manages them through the
# admin surface; the public endpoint's mutations are admin-gated.)
class DisciplinePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # Disciplines are public reference data.
    def resolve = scope.all
  end

  def index?   = true
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
