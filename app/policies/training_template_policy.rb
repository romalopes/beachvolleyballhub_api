# Authorization for reusable training templates.
#
# Reading and writing both require a training manager (coach/curator/admin):
# templates are shared schedule resources, never keyed on `created_by_id`.
class TrainingTemplatePolicy < ApplicationPolicy
  def index?   = content_manager?
  def show?    = content_manager?
  def create?  = content_manager?
  def update?  = content_manager?
  def archive? = content_manager?
  def restore? = content_manager?
  def clone?   = content_manager?
end
