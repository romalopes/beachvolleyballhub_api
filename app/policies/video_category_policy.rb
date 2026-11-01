# Authorization for video categories (public read-only on the API surface;
# management happens through the admin namespace).
class VideoCategoryPolicy < ApplicationPolicy
  def index? = true
  def show?  = true
end
