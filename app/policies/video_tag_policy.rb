# Authorization for video tags (public read-only on the API surface;
# management happens through the admin namespace).
class VideoTagPolicy < ApplicationPolicy
  def index? = true
  def show?  = true
end
